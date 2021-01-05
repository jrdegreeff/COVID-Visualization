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

# ╔═╡ 7ec0992a-4f8e-11eb-3500-53545a706222
md"""
## Data Preparation
"""

# ╔═╡ fd95c222-4cbf-11eb-0690-57cc206d122a
begin
	# Data source: New York Times (https://github.com/nytimes/covid-19-data)
	data_url = "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv"
	covid_data_filename = "data/covid_state_data.csv"
	download(data_url, covid_data_filename)
	covid_data = CSV.read(covid_data_filename, DataFrame)
	indexed_states = collect(covid_data[:, :state])
	unique_states = sort(unique(indexed_states))
	indexed_dates = collect(covid_data[:, :date])
	unique_dates = sort(unique(indexed_dates))
end;

# ╔═╡ aadc3bac-4cc5-11eb-298c-1182973f7011
begin
	# Data source: United States Census Bureau (https://www.census.gov/programs-surveys/popest/technical-documentation/research/evaluation-estimates.html)
	population_data_filename = "data/state_population_data_2020.csv"
	population_data = CSV.read(population_data_filename, DataFrame)
	population_states = collect(population_data[:, :state])
	normalized_covid_data = covid_data[[s ∈ population_states for s in indexed_states], :]
	transform!(normalized_covid_data, [:state, :cases] => ((states, cases) -> 1e5 * cases ./ (s -> population_data[population_states.==s, :population][1]).(states)) => :cases)
	normalized_indexed_states = collect(normalized_covid_data[:, :state])
	normalized_indexed_dates = collect(normalized_covid_data[:, :date])
end;

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
	checkbox = @bind normalize CheckBox(default=true)
	md"""
	Normalize by population $(checkbox)
	"""
end

# ╔═╡ dd4ae0b4-4cc2-11eb-0dad-7de8cb6c055b
begin
	date_slider = @bind date_index Slider(1:length(unique_dates), default=1, show_value=true)
	md"""
	Days Since $(unique_dates[1]): $(date_slider)
	"""
end

# ╔═╡ 3fbcd01c-4cc2-11eb-2613-190f71f8b3c7
md"""
## Plotting Library
"""

# ╔═╡ 4d68678c-4cc2-11eb-1832-9921503256c1
# Function to prepare version of data for a log range
floatify(data, min_value = 0) = Dict(c => map(x -> x > min_value ? x : NaN, d) for (c, d) ∈ data)

# ╔═╡ 6bb8b566-4cc2-11eb-330b-13eae1cc5858
# Function to determine upper bound for a log range
max_value(data) = 10^ceil(Int64, log(10, maximum([d for (_, c) ∈ data for d ∈ c if d !== NaN])))

# ╔═╡ 7a669466-4cc2-11eb-1359-f3f2d060452b
# Function to plot weekly change vs aggregate on a log scale
function plot_covid(aggregate_data, dates, date_index, min_value = 50)
    num_days = length(dates)
    locations = collect(keys(aggregate_data))

    # Weekly change data is the number of new cases in the past week
    weekly_change_data = Dict(c => [d[i] - d[max(1, i - 6)] for i ∈ 1:num_days] for (c, d) ∈ aggregate_data)
	
	# Average daily change data is the average number of new cases per day in the past week
	average_daily_change_data = Dict(c => [(d[i] - d[max(1, i - 6)]) / 7 for i ∈ 1:num_days] for (c, d) ∈ aggregate_data)

    # Only show when total cases > min_value
    aggregate_data = floatify(aggregate_data, min_value)
    weekly_change_data = floatify(weekly_change_data)
    average_daily_change_data = floatify(average_daily_change_data)

	p = plot(xscale=:log10, yscale=:log10, leg=:bottomright)
	xlims!(10^floor(Int64, log(10, min_value)), max_value(aggregate_data))
	ylims!(1, max_value(weekly_change_data))
	for (i, c) in enumerate(locations)
		plot!(
			aggregate_data[c][1:date_index],
			weekly_change_data[c][1:date_index],
			color=i,
			label=false
		)
		if !isnan(aggregate_data[c][date_index]) && !isnan(weekly_change_data[c][date_index])
			scatter!(
				aggregate_data[c][date_index:date_index],
				weekly_change_data[c][date_index:date_index],
				color=i,
				label=c
			)
		end
	end
	xlabel!(normalize ? "Total Confirmed Cases per 100,000 Residents" : "Total Confirmed Cases")
	ylabel!(normalize ? "Recent Confirmed Cases per 100,000 Residents" : "Recent Confirmed Cases")
	title!("Trajectory of COVID-19 Confirmed Cases ($(dates[date_index]))")
	p |> as_svg
end

# ╔═╡ 2180a1f4-4f8b-11eb-073b-4f671634dc37
md"""
## Library Overrides
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
		plot_covid(aggregate_data, unique_dates, date_index, 100)
	end
end

# ╔═╡ Cell order:
# ╟─073afcbe-4cbf-11eb-33a8-a327232257eb
# ╟─7ec0992a-4f8e-11eb-3500-53545a706222
# ╠═fd95c222-4cbf-11eb-0690-57cc206d122a
# ╠═aadc3bac-4cc5-11eb-298c-1182973f7011
# ╠═9e089168-4cc1-11eb-023a-8d7cfd681e88
# ╟─70496912-4f8e-11eb-28ca-c50ae0af115e
# ╟─b9c78b8a-4edf-11eb-0a36-c72d60e4680a
# ╟─b7aa216e-4f8d-11eb-339c-394d2c23ee4f
# ╟─dd4ae0b4-4cc2-11eb-0dad-7de8cb6c055b
# ╟─c60b7e00-4cc1-11eb-2e78-c1a55563de15
# ╟─3fbcd01c-4cc2-11eb-2613-190f71f8b3c7
# ╟─4d68678c-4cc2-11eb-1832-9921503256c1
# ╟─6bb8b566-4cc2-11eb-330b-13eae1cc5858
# ╟─7a669466-4cc2-11eb-1359-f3f2d060452b
# ╟─2180a1f4-4f8b-11eb-073b-4f671634dc37
# ╟─318885e6-4f8b-11eb-2b78-49f08e7074fc
