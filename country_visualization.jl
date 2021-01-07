### A Pluto.jl notebook ###
# v0.12.18

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 4a425262-509a-11eb-08ac-cd5457e6c813
begin
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add([
			"CSV",
			"DataFrames",
			"Plots",
			"PlutoUI",
	])
	using CSV
	using DataFrames
	using Dates
	using InteractiveUtils
	using Markdown
	using Statistics
	using Plots
	using PlutoUI
end

# ╔═╡ 6c0d01d0-509a-11eb-2179-cbd8c3ec59d2
md"""
# International COVID-19 Visualization
This is a visualization of weekly reported COVID-19 cases against total reported cases. The plot is done on a log-scale causing exponential growth to be represented linearly. Since time is not explicitly represented on the graph, direct comparisons can be drawn between countries who experienced similar case trends at different times.

This project was created by Jeremiah DeGreeff with inspiration from Problem Set 1 for [MIT Course 6.S083 Spring 2020](https://www.eecs.mit.edu/academics-admissions/academic-information/subject-updates-spring-2020/6s083) and [this visualization](https://aatishb.com/covidtrends/) created by Aatish Bhatia.
"""

# ╔═╡ bf71b0fa-509a-11eb-36d7-9fb6af718625
md"""
## Data Preparation
"""

# ╔═╡ cc72d7a2-509a-11eb-3515-b70d385cd79e
begin
	data_url = "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv"
	md"""
	COVID-19 Cases Data Source: [JHU CSSE](https://github.com/CSSEGISandData/COVID-19)
	"""
end

# ╔═╡ 0f6c6f82-509b-11eb-21ae-bb984f52b4d4
begin
	filename = "data/covid_country_data.csv"
	download(data_url, filename)
	all_data = CSV.read(filename, DataFrame)
	rename!(all_data, 1 => "province", 2 => "country")
	
	# Enumerate all countries
	all_countries = collect(all_data[:, 2])
	unique_countries = unique(all_countries)
	
	# Extract the dates we want to plot
	format = Dates.DateFormat("m/d/Y")
	date_strings = String.(names(all_data)[5:end])
	dates = parse.(Date, date_strings, format) .+ Year(2000)
	
	all_data
end

# ╔═╡ c31e21ce-509b-11eb-3ed5-ab97c8adb545
begin
	date_slider = @bind date_index Slider(1:length(dates), default=1, show_value=true)
	md"""
	Days since $(dates[1]): $(date_slider)
	"""
end

# ╔═╡ d2af04be-509b-11eb-2b1b-65d6b02ba7db
begin
	double_rate_slider = @bind double_rate Slider(1:100, default=7, show_value=true)
	md"""
	Exponential growth doubling rate (in days): $(double_rate_slider)
	"""
end

# ╔═╡ da696e06-509b-11eb-2a3c-8fc8c4fb3039
begin
	legend_checkbox = @bind legend CheckBox(default=true)
	md"""
	Show legend $(legend_checkbox)
	"""
end

# ╔═╡ df9860c6-509b-11eb-307c-7bd5236d725c
md"""
## Plotting Library
"""

# ╔═╡ e64c39c4-509b-11eb-361c-771e9909c07b
# Function to apply a function over a dictionary of data sequences
apply_over_dict(func, dict, args=()) = Dict(k => isempty(args) ? func(v) : func(v, args) for (k,v) ∈ dict)

# ╔═╡ edb8991e-509b-11eb-24ea-4dca6c092374
# Function to convert aggregate data to weekly data
aggreggate_to_weekly_change(aggregate_data) = [aggregate_data[i] -  aggregate_data[max(1, i - 6)] for i ∈ 1:length(aggregate_data)]

# ╔═╡ f81bc298-509b-11eb-2a44-4f46c85811c1
# Function to prepare version of data for a log range
truncate(data, min_value = 0) = map(x -> x > min_value ? x : NaN, data)

# ╔═╡ fd74fe2e-509b-11eb-019b-493a9a1eb249
# Function to determine upper bound for a log range
max_value(data) = 10^ceil(Int64, log(10, maximum([d for (_, s) ∈ data for d ∈ s if !isnan(d)])))

# ╔═╡ 04546f7c-509c-11eb-361d-3dac17d55476
# Function to plot weekly change vs aggregate on a log scale
function plot_covid(aggregate_data, dates, date_index; min_value = 10, double_rate = missing, normalize = false)
	p = plot(xscale=:log10, yscale=:log10, leg=:bottomright)
	title!("Trajectory of COVID-19 Confirmed Cases ($(dates[date_index]))")
	xlabel!(normalize ? "Total Confirmed Cases per 100,000 Residents" : "Total Confirmed Cases")
	ylabel!(normalize ? "Recent Confirmed Cases per 100,000 Residents" : "Recent Confirmed Cases")
	
    # Weekly change data is the number of new cases in the past week
    weekly_change_data = apply_over_dict(aggreggate_to_weekly_change, aggregate_data)
	
	aggregate_data = apply_over_dict(truncate, aggregate_data, min_value)
    weekly_change_data = apply_over_dict(truncate, weekly_change_data)
	
	min_x = 10^floor(Int64, log(10, min_value))
	if all(s -> all(isnan, s), values(aggregate_data))
		x_range = (min_x, min_x * 10)
		y_range = (1, 10)
	else
		x_range = (min_x, max_value(aggregate_data))
		y_range = (1, max_value(weekly_change_data))
	end
	xlims!(x_range)
	ylims!(y_range)
	
	for (i, c) in enumerate(keys(aggregate_data))
		plot!(aggregate_data[c][1:date_index], weekly_change_data[c][1:date_index], color=i, label=false)
		if !isnan(aggregate_data[c][date_index]) && !isnan(weekly_change_data[c][date_index])
			scatter!(aggregate_data[c][date_index:date_index], weekly_change_data[c][date_index:date_index], color=i, label=c, markerstrokewidth=0)
		end
	end
	
	if !ismissing(double_rate)
		# Exponential data provides a reference for what pure exponential growth with a particular growth rate would look like
		exponential_aggregate = [2^(t / double_rate) for t ∈ 0:ceil(log2(x_range[2]) * double_rate)]
		exponential_weekly_change = aggreggate_to_weekly_change(exponential_aggregate)

		exponential_aggregate = truncate(exponential_aggregate)
		exponential_weekly_change = truncate(exponential_weekly_change)

		plot!(exponential_aggregate, exponential_weekly_change, color=:gray, lw=2, label="Exponential Growth (d=$(double_rate))")
	end
	p
end

# ╔═╡ 7639ff12-509c-11eb-3215-b108ab8d04af
md"""
## PlutoUI Library Overrides
"""

# ╔═╡ 782fc4be-509c-11eb-0e53-bbad102c817d
begin
	import Markdown: htmlesc, withtag
	
    struct MultiSelect
        options::Array{Pair{<:AbstractString,<:Any},1}
        default::Union{Missing, AbstractVector{AbstractString}}
        size::Int
    end
    
	MultiSelect(options::Array{<:AbstractString,1}; default=missing, size=5) = MultiSelect([o => o for o in options], default, size)
    MultiSelect(options::Array{<:Pair{<:AbstractString,<:Any},1}; default=missing, size=5) = MultiSelect(options, default, size)
    
	function Base.show(io::IO, ::MIME"text/html", select::MultiSelect)
        withtag(io, Symbol("select multiple"), :size => string(select.size)) do
            for o in select.options
                print(io, """<option value="$(htmlesc(o.first))"$(!ismissing(select.default) && o.first ∈ select.default ? " selected" : "")>""")
                if showable(MIME"text/html"(), o.second)
                    show(io, MIME"text/html"(), o.second)
                else
                    print(io, o.second)
                end
                print(io, "</option>")
            end
        end
    end
    
	Base.get(select::MultiSelect) = ismissing(select.default) ? Any[] : select.default
end

# ╔═╡ 643690d0-509c-11eb-14e0-3ff522e70c9b
begin
	select = @bind countries MultiSelect(unique_countries, size=length(unique_countries))
    md"""
    Select the countries to display.

    $(select)
    """
end

# ╔═╡ 7cca2120-509b-11eb-17a5-e36d54879f37
begin
	if !isempty(countries)
aggregate_data = Dict(c => collect(mapcols(sum, all_data[all_countries.==c, :][:, 5:end])[1, :]) for c ∈ countries)
		p = plot_covid(aggregate_data, dates, date_index; min_value=100, double_rate=double_rate)
		if !legend plot!(p, leg=false) end
		p |> as_svg
	end
end

# ╔═╡ Cell order:
# ╟─4a425262-509a-11eb-08ac-cd5457e6c813
# ╟─6c0d01d0-509a-11eb-2179-cbd8c3ec59d2
# ╟─bf71b0fa-509a-11eb-36d7-9fb6af718625
# ╟─cc72d7a2-509a-11eb-3515-b70d385cd79e
# ╟─0f6c6f82-509b-11eb-21ae-bb984f52b4d4
# ╟─643690d0-509c-11eb-14e0-3ff522e70c9b
# ╟─c31e21ce-509b-11eb-3ed5-ab97c8adb545
# ╟─d2af04be-509b-11eb-2b1b-65d6b02ba7db
# ╟─da696e06-509b-11eb-2a3c-8fc8c4fb3039
# ╟─7cca2120-509b-11eb-17a5-e36d54879f37
# ╟─df9860c6-509b-11eb-307c-7bd5236d725c
# ╟─e64c39c4-509b-11eb-361c-771e9909c07b
# ╟─edb8991e-509b-11eb-24ea-4dca6c092374
# ╟─f81bc298-509b-11eb-2a44-4f46c85811c1
# ╟─fd74fe2e-509b-11eb-019b-493a9a1eb249
# ╟─04546f7c-509c-11eb-361d-3dac17d55476
# ╟─7639ff12-509c-11eb-3215-b108ab8d04af
# ╟─782fc4be-509c-11eb-0e53-bbad102c817d
