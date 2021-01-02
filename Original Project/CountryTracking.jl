# Author: Jeremiah DeGreeff
# Date: 5/24/2020
# Ported from problem set 1 for 6.S083

using CSV
using DataFrames
using Dates

include("COVIDPlot.jl")

# Data source: JHU CSSE (https://github.com/CSSEGISandData/COVID-19)
data_url = "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv"
filename = "covid_country_data.csv"
download(data_url, filename)
all_data = CSV.read(filename)
rename!(all_data, 1 => "province", 2 => "country")

# Enumerate all countries
all_countries = collect(all_data[:, 2])

# Enumerate the countries we want to plot
countries = [
    "Brazil",
    "China",
    "France",
    "Germany",
    "India",
    "Italy",
    "Japan",
    "Russia",
    "Spain",
    "Korea, South",
    "United Kingdom",
    "US",
]

# Extract the dates we want to plot
format = Dates.DateFormat("m/d/Y")
date_strings = String.(names(all_data)[5:end])
dates = parse.(Date, date_strings, format) .+ Year(2000)

# Aggregate data is total cases to date in a particular country
aggregate_data = Dict(
    c => collect(mapcols(sum, all_data[all_countries.==c, :][:, 5:end])[1, :]) for c ∈ countries
)

# Plot weekly change vs aggregate on a log scale
plot_covid(aggregate_data, dates)
