# Author: Jeremiah DeGreeff
# Date: 5/24/2020

using CSV
using DataFrames
using Dates

include("COVIDPlot.jl")

# Data source: New York Times (https://github.com/nytimes/covid-19-data)
data_url = "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv"
filename = "covid_state_data.csv"
download(data_url, filename)
all_data = CSV.read(filename)

# Enumerate all states
all_states = collect(all_data[:, 2])

# Enumerate the states we want to plot
north_east = [
    "Connecticut",
    "Maine",
    "Massachusetts",
    "New Hampshire",
    "New Jersey",
    "New York",
    "Rhode Island",
    "Vermont",
]
south = [
    "Alabama",
    "Florida",
    "Georgia",
    "Louisiana",
    "Mississippi",
    "South Carolina",
    "Texas",
]
states = [
    # "Alaska",
    # "Arizona",
    "California",
    # "Connecticut",
    "Florida",
    # "Illinois",
    # "Maine",
    # "Maryland",
    "Massachusetts",
    # "Michigan",
    # "New Hampshire",
    # "New Jersey",
    "New York",
    # "Rhode Island",
    "Texas",
    # "Vermont",
    # "Washington",
    # "Wisconsin",
]
# states = north_east
states = south

# Extract the dates we want to plot
all_dates = collect(all_data[:, 1])
dates = unique(all_dates)

# Function to extract case count for a state on a day
function get_case_count(state, date)
    cases = all_data[(all_states.==state).*(all_dates.==date), 4]
    return length(cases) > 0 ? cases[1] : 0
end

# Aggregate data is total cases to date in a particular state
aggregate_data = Dict(s => [get_case_count(s, d) for d ∈ dates] for s ∈ states)

# Plot weekly change vs aggregate on a log scale
plot_covid(aggregate_data, dates, 10)
