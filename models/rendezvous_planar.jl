#= Planar spacecraft rendezvous data structures and custom methods..

Sequential convex programming algorithms for trajectory optimization.
Copyright (C) 2021 Autonomous Controls Laboratory (University of Washington)

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>. =#

include("../core/scp.jl")

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# :: Data structures ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

""" Planar rendezvous parameters. """
struct PlanarRendezvousParameters
    # ..:: Indices ::..
    id_r::T_IntVector # Position (state)
    id_v::T_IntVector # Velocity (state)
    id_θ::T_Int       # Rotation angle (state)
    id_ω::T_Int       # Rotation rate (state)
    id_fm::T_Int      # Thrust force of lower (-) RCS pod (input)
    id_fp::T_Int      # Thrust force of upper (+) RCS pod (input)
    id_f0::T_Int      # Thrust force of vertical (0) RCS pod (input)
    id_t::T_Int       # Time dilation (parameter)
    # ..:: Mechanical parameters ::..
    m::T_Real         # [kg] Mass
    J::T_Real         # [kg*m²] Moment of inertia about CoM
    lu::T_Real        # [m] CoM longitudinal distance aft of thrusters
    lv::T_Real        # [m] CoM transverse distance from thrusters
    uh::T_Function    # Longitudinal "forward" axis in the inertial frame
    vh::T_Function    # Transverse "up" axis in the inertial frame
    # ..:: Control parameters ::..
    f_max::T_Real     # [N] Maximum thrust force
    f_db::T_Real      # [N] Deadband thrust force
end

""" Planar rendezvous flight environment. """
struct PlanarRendezvousEnvironmentParameters
    xh::T_RealVector # Inertial horizontal axis
    yh::T_RealVector # Inertial vertical axis
    n::T_Real        # [rad/s] Orbital mean motion
end

""" Trajectory parameters. """
struct PlanarRendezvousTrajectoryParameters
    r0::T_RealVector # [m] Initial position
    v0::T_RealVector # [m/s] Initial velocity
    θ0::T_Real       # [rad] Initial rotation angle
    ω0::T_Real       # [rad/s] Initial rotation rate
    vf::T_Real       # [m/s] Final approach speed
    tf_min::T_Real   # [s] Minimum flight time
    tf_max::T_Real   # [s] Maximum flight time
end

""" Planar rendezvous trajectory optimization problem parameters all in
one. """
struct PlanarRendezvousProblem
    vehicle::PlanarRendezvousParameters        # The ego-vehicle
    env::PlanarRendezvousEnvironmentParameters # The environment
    traj::PlanarRendezvousTrajectoryParameters # The trajectory
end

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# :: Constructors :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

"""
    PlanarRendezvousProblem()

Constructor for the planar rendezvous problem.

# Returns
- `mdl`: the problem definition object.
"""
function PlanarRendezvousProblem()::PlanarRendezvousProblem

    # ..:: Environment ::..
    xh = [1.0; 0.0]
    yh = [0.0; 1.0]
    μ = 3.986e14 # [m³/s²] Standard gravitational parameter
    Re = 6378e3 # [m] Earth radius
    R = Re+400e3 # [m] Orbit radius
    n = sqrt(μ/R^3)
    env = PlanarRendezvousEnvironmentParameters(xh, yh, n)

    # ..:: Spacecraft vehicle ::..
    # >> Indices <<
    id_r = 1:2
    id_v = 3:4
    id_θ = 5
    id_ω = 6
    id_fm = 1
    id_fp = 2
    id_f0 = 3
    id_t = 1
    # >> Mechanical parameters <<
    m = 30e3
    J = 1e5
    lu = 0.6
    lv = 2.1
    uh = (θ) -> -cos(θ)*xh+sin(θ)*yh
    vh = (θ) -> -sin(θ)*xh-cos(θ)*yh
    # >> Control parameters <<
    f_max = 445.0
    f_db = 50.0

    sc = PlanarRendezvousParameters(
        id_r, id_v, id_θ, id_ω, id_fm, id_fp, id_f0, id_t, m,
        J, lu, lv, uh, vh, f_max, f_db)

    # ..:: Trajectory ::..
    r0 = 100.0*xh+0.0*yh
    v0 = 0.0*xh
    θ0 = deg2rad(180.0)
    ω0 = 0.0
    vf = 0.1
    tf_min = 100.0
    tf_max = 400.0
    traj = PlanarRendezvousTrajectoryParameters(
        r0, v0, θ0, ω0, vf, tf_min, tf_max)

    mdl = PlanarRendezvousProblem(sc, env, traj)

    return mdl
end

# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# :: Public methods :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

"""
    plot_final_trajectory(mdl, sol)

Plot the final converged trajectory.

# Arguments
- `mdl`: the planar rendezvous problem parameters.
- `sol`: the trajectory solution.
"""
function plot_final_trajectory(mdl::PlanarRendezvousProblem,
                               sol::SCPSolution)::Nothing

    # Common values
    algo = sol.algo
    dt_clr = get_colormap()(1.0)
    N = size(sol.xd, 2)
    speed = [norm(@k(sol.xd[mdl.vehicle.id_v, :])) for k=1:N]
    v_cmap = plt.get_cmap("inferno")
    v_nrm = matplotlib.colors.Normalize(vmin=minimum(speed),
                                        vmax=maximum(speed))
    v_cmap = matplotlib.cm.ScalarMappable(norm=v_nrm, cmap=v_cmap)
    u_scale = 0.2

    fig = create_figure((10, 4))
    ax = fig.add_subplot()

    ax.grid(linewidth=0.3, alpha=0.5)
    ax.set_axisbelow(true)
    ax.set_facecolor("white")

    ax.set_xlabel("Inertial \$x\$ [m]")
    ax.set_ylabel("Inertial \$y\$ [m]")

    # Colorbar for velocity norm
    plt.colorbar(v_cmap,
                 aspect=40,
                 label="Velocity \$\\|v\\|_2\$ [m/s]")

    # ..:: Draw the final continuous-time position trajectory ::..

    # Collect the continuous-time trajectory data
    ct_res = 1000
    ct_τ = T_RealArray(LinRange(0.0, 1.0, ct_res))
    ct_pos = T_RealMatrix(undef, 2, ct_res)
    ct_speed = T_RealVector(undef, ct_res)
    for k = 1:ct_res
        xk = sample(sol.xc, @k(ct_τ))
        @k(ct_pos) = xk[mdl.vehicle.id_r]
        @k(ct_speed) = norm(xk[mdl.vehicle.id_v])
    end

    # Plot the trajectory
    for k = 1:ct_res-1
        r, v = @k(ct_pos), @k(ct_speed)
        x, y = r
        ax.plot(x, y,
                linestyle="none",
                marker="o",
                markersize=4,
                alpha=0.15,
                markerfacecolor=v_cmap.to_rgba(v),
                markeredgecolor="none",
                zorder=10)
    end

    # ..:: Discrete-time positions trajectory ::..
    pos = sol.xd[mdl.vehicle.id_r, :]
    x, y = pos[1, :], pos[2, :]
    ax.plot(x, y,
            linestyle="none",
            marker="o",
            markersize=3,
            markerfacecolor=dt_clr,
            markeredgecolor="white",
            markeredgewidth=0.3,
            label="\$r\$",
            zorder=20)

    y_lim = 5
    # set_axis_equal(ax, (-1.5, missing, -y_lim, y_lim))

    save_figure("rendezvous_planar_traj", algo)

    return nothing
end

"""
    plot_attitude(mdl, sol)

Plot the converged attitude trajectory.

# Arguments
- `mdl`: the planar rendezvous problem parameters.
- `sol`: the trajectory solution.
"""
function plot_attitude(mdl::PlanarRendezvousProblem,
                       sol::SCPSolution)::Nothing

    # Common values
    algo = sol.algo
    veh = mdl.vehicle
    N = size(sol.xd, 2)
    tf = sol.p[veh.id_t]
    veh = mdl.vehicle
    traj = mdl.traj
    ct_res = 500
    td = T_RealVector(LinRange(0.0, 1.0, N))*tf
    τc = T_RealVector(LinRange(0.0, 1.0, ct_res))
    tc = τc*tf
    clr = get_colormap()(1.0)

    fig = create_figure((6, 6))

    # Plot data
    data = [Dict(:ylabel=>"Angle [\$^\\circ\$]",
                 :scale=>(θ)->θ*180/pi,
                 :dt_y=>sol.xd,
                 :ct_y=>sol.xc,
                 :id=>veh.id_θ),
            Dict(:ylabel=>"Angular rate [\$^\\circ\$/s]",
                 :scale=>(ω)->ω*180/pi,
                 :dt_y=>sol.xd,
                 :ct_y=>sol.xc,
                 :id=>veh.id_ω)]

    axes = []

    for i = 1:length(data)
        ax = fig.add_subplot(length(data), 1, i)
        push!(axes, ax)

        ax.grid(linewidth=0.3, alpha=0.5)
        ax.set_axisbelow(true)
        ax.set_facecolor("white")
        ax.autoscale(tight=true, axis="x")

        ax.set_xlabel("Time [s]")
        ax.set_ylabel(data[i][:ylabel])

        x = data[i][:dt_y][data[i][:id], :]
        x = map(data[i][:scale], x)

        ax.plot(td, x,
                linestyle="none",
                marker="o",
                markersize=4,
                markerfacecolor=clr,
                markeredgewidth=0,
                zorder=10,
                clip_on=false)

        # >> Final continuous-time solution <<
        yc = hcat([data[i][:scale](sample(data[i][:ct_y], τ)[data[i][:id]])
                   for τ in τc]...)
        ax.plot(tc, yc[:],
                color=clr,
                linewidth=2,
                zorder=10)

    end

    fig.align_ylabels(axes)

    save_figure("rendezvous_planar_attitude", algo)

    return nothing
end
