# Author: Jeremiah DeGreeff
# Date: 5/24/2020
# Ported from problem set 1 for 6.S083

using Plots
using Interact

# Function to prepare version of data for a log range
floatify(data, min_value = 0) =
    Dict(c => map(x -> x > min_value ? x : NaN, d) for (c, d) ∈ data)

# Function to determine upper bound for a log range
max_value(data) =
    10^ceil(
        Int64,
        log(10, maximum([d for (_, c) ∈ data for d ∈ c if d !== NaN])),
    )

# Function to plot weekly change vs aggregate on a log scale
function plot_covid(aggregate_data, dates, min_value = 50)
    num_days = length(dates)
    locations = collect(keys(aggregate_data))

    # Weekly change data is the number of new cases in the past week
    weekly_change_data = Dict(
        c => [d[i] - d[max(1, i - 6)] for i ∈ 1:num_days] for (c, d) ∈ aggregate_data
    )

    # Only show when total cases > 50, as in the original visualization
    aggregate_data = floatify(aggregate_data, min_value)
    weekly_change_data = floatify(weekly_change_data)

    label = "Days Since $(dates[1])"
    @manipulate for offset ∈
                    slider(0:num_days-1, value = num_days - 1, label = label)
        t = offset + 1

        plot(xscale = :log10, yscale = :log10, leg = false)
        xlims!(10^floor(Int64, log(10, min_value)), max_value(aggregate_data))
        ylims!(1, max_value(weekly_change_data))
        for (i, c) in enumerate(locations)
            plot!(aggregate_data[c][1:t], weekly_change_data[c][1:t], color = i)
            if isnan(aggregate_data[c][t]) || isnan(weekly_change_data[c][t])
                continue
            end
            scatter!(
                aggregate_data[c][t:t],
                weekly_change_data[c][t:t],
                color = i,
            )
            annotate!(
                aggregate_data[c][t],
                weekly_change_data[c][t] * 1.5,
                text(c, 6, :black),
            )
        end
        xlabel!("Total Confirmed Cases")
        ylabel!("New Confirmed Cases (In the Past Week)")
        title!("Trajectory of COVID-19 Confirmed Cases ($(dates[t]))")
    end
end
