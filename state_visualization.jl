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

# ╔═╡ 073afcbe-4cbf-11eb-33a8-a327232257eb
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

# ╔═╡ 1b720d94-4f8f-11eb-0baf-bbcd93231972
md"""
# United States COVID-19 Visualization
This is a visualization of weekly reported COVID-19 cases against total reported cases. The plot is done on a log-scale causing exponential growth to be represented linearly. Since time is not explicitly represented on the graph, direct comparisons can be drawn between states who experienced similar case trends at different times. The visualization also provides an option to normalize for population data to give a better comparison for states with vastly different populations.

This project was created by Jeremiah DeGreeff with inspiration from Problem Set 1 for [MIT Course 6.S083 Spring 2020](https://www.eecs.mit.edu/academics-admissions/academic-information/subject-updates-spring-2020/6s083) and [this visualization](https://aatishb.com/covidtrends/) created by Aatish Bhatia.
"""

# ╔═╡ 7ec0992a-4f8e-11eb-3500-53545a706222
md"""
## Data Preparation
"""

# ╔═╡ 2bd8a378-4f8f-11eb-3e67-ed3ed64e820c
begin
	data_url = "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv"
	md"""
	US State COVID-19 Data Source: [New York Times](https://github.com/nytimes/covid-19-data)
	"""
end

# ╔═╡ fd95c222-4cbf-11eb-0690-57cc206d122a
begin
	covid_data_filename = "data/covid_state_data.csv"
	download(data_url, covid_data_filename)
	covid_data = CSV.read(covid_data_filename, DataFrame)
	indexed_states = collect(covid_data[:, :state])
	unique_states = sort(unique(indexed_states))
	indexed_dates = collect(covid_data[:, :date])
	unique_dates = sort(unique(indexed_dates))
	covid_data
end

# ╔═╡ 4f0a03d2-4f8f-11eb-3f36-edbec0b6a9c3
md"""
US State Population Data Source: [United States Census Bureau](https://www.census.gov/programs-surveys/popest/technical-documentation/research/evaluation-estimates.html)
"""

# ╔═╡ aadc3bac-4cc5-11eb-298c-1182973f7011
begin
	population_data_filename = "data/state_population_data_2020.csv"
	population_data = CSV.read(population_data_filename, DataFrame)
	population_states = collect(population_data[:, :state])
	normalized_covid_data = covid_data[[s ∈ population_states for s in indexed_states], :]
	transform!(normalized_covid_data, [:state, :cases] => ((states, cases) -> 1e5 * cases ./ (s -> population_data[population_states.==s, :population][1]).(states)) => :cases)
	normalized_indexed_states = collect(normalized_covid_data[:, :state])
	normalized_indexed_dates = collect(normalized_covid_data[:, :date])
	population_data
end

# ╔═╡ 9e089168-4cc1-11eb-023a-8d7cfd681e88
# Function to extract case count for a state on a day
function get_case_count(state, date, normalize=false)
	if normalize
		@assert state in population_states
    	cases = normalized_covid_data[(normalized_indexed_states.==state).*(normalized_indexed_dates.==date), :cases]
	else
		@assert state in unique_states
    	cases = covid_data[(indexed_states.==state).*(indexed_dates.==date), :cases]
	end
	@assert length(cases) < 2
    return length(cases) == 1 ? cases[1] : 0
end;

# ╔═╡ 70496912-4f8e-11eb-28ca-c50ae0af115e
md"""
## Visualization
"""

# ╔═╡ b9c78b8a-4edf-11eb-0a36-c72d60e4680a
begin
	normalize_checkbox = @bind normalize CheckBox(default=true)
	md"""
	Normalize by population $(normalize_checkbox)
	"""
end

# ╔═╡ dd4ae0b4-4cc2-11eb-0dad-7de8cb6c055b
begin
	date_slider = @bind date_index Slider(1:length(unique_dates), default=1, show_value=true)
	md"""
	Days since $(unique_dates[1]): $(date_slider)
	"""
end

# ╔═╡ e7871fa2-4f9c-11eb-0d97-f7040e7c285c
begin
	double_rate_slider = @bind double_rate Slider(1:100, default=7, show_value=true)
	md"""
	Exponential growth doubling rate (in days): $(double_rate_slider)
	"""
end

# ╔═╡ 68593592-4f9e-11eb-2fac-bb30829cb8f0
begin
	legend_checkbox = @bind legend CheckBox(default=true)
	md"""
	Show legend $(legend_checkbox)
	"""
end

# ╔═╡ 3fbcd01c-4cc2-11eb-2613-190f71f8b3c7
md"""
## Plotting Library
"""

# ╔═╡ 513019c0-4f9a-11eb-1086-b795d60a5b50
# Function to apply a function over a dictionary of data sequences
apply_over_dict(func, dict, args=()) = Dict(k => isempty(args) ? func(v) : func(v, args) for (k,v) ∈ dict)

# ╔═╡ 54673912-4f99-11eb-36ca-9b0124ed444b
# Function to convert aggregate data to weekly data
aggreggate_to_weekly_change(aggregate_data) = [aggregate_data[i] -  aggregate_data[max(1, i - 6)] for i ∈ 1:length(aggregate_data)]

# ╔═╡ 76fb1292-4f95-11eb-1824-4d5437b91463
# Function to prepare version of data for a log range
truncate(data, min_value = 0) = map(x -> x > min_value ? x : NaN, data)

# ╔═╡ 6bb8b566-4cc2-11eb-330b-13eae1cc5858
# Function to determine upper bound for a log range
max_value(data) = 10^ceil(Int64, log(10, maximum([d for (_, s) ∈ data for d ∈ s if !isnan(d)])))

# ╔═╡ 7a669466-4cc2-11eb-1359-f3f2d060452b
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

# ╔═╡ 2180a1f4-4f8b-11eb-073b-4f671634dc37
md"""
## PlutoUI Library Overrides
"""

# ╔═╡ 318885e6-4f8b-11eb-2b78-49f08e7074fc
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

# ╔═╡ b7aa216e-4f8d-11eb-339c-394d2c23ee4f
begin
	state_options = normalize ? population_states : unique_states
	select = @bind states MultiSelect(state_options, size=length(state_options))
    md"""
    Select the states to display.

    $(select)
    """
end

# ╔═╡ c60b7e00-4cc1-11eb-2e78-c1a55563de15
begin
	if !isempty(states)
		aggregate_data = Dict(s => [get_case_count(s, d, normalize) for d ∈ unique_dates] for s ∈ states)
		p = plot_covid(aggregate_data, unique_dates, date_index; double_rate=double_rate, normalize=normalize)
		if !legend plot!(p, leg=false) end
		p |> as_svg
	end
end

# ╔═╡ Cell order:
# ╟─073afcbe-4cbf-11eb-33a8-a327232257eb
# ╟─1b720d94-4f8f-11eb-0baf-bbcd93231972
# ╟─7ec0992a-4f8e-11eb-3500-53545a706222
# ╟─2bd8a378-4f8f-11eb-3e67-ed3ed64e820c
# ╟─fd95c222-4cbf-11eb-0690-57cc206d122a
# ╟─4f0a03d2-4f8f-11eb-3f36-edbec0b6a9c3
# ╟─aadc3bac-4cc5-11eb-298c-1182973f7011
# ╟─9e089168-4cc1-11eb-023a-8d7cfd681e88
# ╟─70496912-4f8e-11eb-28ca-c50ae0af115e
# ╟─b9c78b8a-4edf-11eb-0a36-c72d60e4680a
# ╟─b7aa216e-4f8d-11eb-339c-394d2c23ee4f
# ╟─dd4ae0b4-4cc2-11eb-0dad-7de8cb6c055b
# ╟─e7871fa2-4f9c-11eb-0d97-f7040e7c285c
# ╟─68593592-4f9e-11eb-2fac-bb30829cb8f0
# ╟─c60b7e00-4cc1-11eb-2e78-c1a55563de15
# ╟─3fbcd01c-4cc2-11eb-2613-190f71f8b3c7
# ╟─513019c0-4f9a-11eb-1086-b795d60a5b50
# ╟─54673912-4f99-11eb-36ca-9b0124ed444b
# ╟─76fb1292-4f95-11eb-1824-4d5437b91463
# ╟─6bb8b566-4cc2-11eb-330b-13eae1cc5858
# ╟─7a669466-4cc2-11eb-1359-f3f2d060452b
# ╟─2180a1f4-4f8b-11eb-073b-4f671634dc37
# ╟─318885e6-4f8b-11eb-2b78-49f08e7074fc
