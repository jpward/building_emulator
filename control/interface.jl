##This module is an example julia-based testing interface.  It uses the
###``requests`` package to make REST API calls to the test case container,
###which mus already be running.  A controller is tested, which is
###imported from a different module.

# GENERAL PACKAGE IMPORT
# ----------------------
using HTTP, JSON, CSV, DataFrames, Dates

# TEST CONTROLLER IMPORT
# ----------------------
include("./controllers.jl")
using .con

# SETUP TEST CASE
# ---------------
# Set URL for testcase
url = "http://emulator:5000"
length = 86400
step = 600
# ---------------

# GET TEST INFORMATION
# --------------------
println("TEST CASE INFORMATION ------------- \n")
# Test case name
name = JSON.parse(String(HTTP.get("$url/name").body))
println("Name:\t\t\t$name")

# Inputs available
inputs = JSON.parse(String(HTTP.get("$url/inputs").body))
# println("Control Inputs:\t\t\t$inputs")
# Measurements available
measurements = JSON.parse(String(HTTP.get("$url/measurements").body))
#println("Measurements:\t\t\t$measurements")

# Default simulation step
step_def = JSON.parse(String(HTTP.get("$url/step").body))
println("Default Simulation Step:\t$step_def")

# store measurements and inputs in csv file
df = DataFrame(Control_inputs=inputs)
CSV.write("control_inputs.csv", sort!(df))
df = DataFrame(Measurements=measurements)
CSV.write("measurements.csv", sort!(df))

# RUN TEST CASE
#----------
start_test = Dates.now()
# Reset test case
println("Resetting test case if needed.")
start=86400*200
res = HTTP.put("$url/reset",["Content-Type" => "application/json"], JSON.json(Dict("start" => start)))
println("Running test case ...")
# Set simulation step
println("Setting simulation step to $step")
res = HTTP.put("$url/step",["Content-Type" => "application/json"], JSON.json(Dict("step" => step)))

# simulation loop
for i = 1:convert(Int, floor(length/step))
    if i<2
    # Initialize u
       u = con.initialize()
    else
    # Compute next control signal
       u = con.compute_control(y)
    end
    # Advance in simulation
    res=HTTP.post("$url/advance", ["Content-Type" => "application/json"], JSON.json(u);retry_non_idempotent=true).body
    global y = JSON.parse(String(res))
end

println("Test case complete.")
time=(Dates.now()-start_test).value/1000.
println("Elapsed time of test was $time seconds.")

# --------------------
# POST PROCESS RESULTS
# --------------------
# Get result data
res = JSON.parse(String(HTTP.get("$url/results").body))

time = [x/3600 for x in res["y"]["time"]] # convert s --> hr
# add whatever variables you want to add
TRooAir  = [x-273.15 for x in res["y"]["floor1_zon2_TRooAir_y"]] # convert K --> C

# adding column names
colnames = ["time", "TRooAir"]
tab=DataFrame([time,TRooAir])
names!(tab, Symbol.(colnames))
CSV.write("result_testcase2.csv",tab)

# stop the emulator
HTTP.put("$url/stop")