"""
How to run
In the terminal type 
julia eco.jl

or
in the Julia repl type
include("eco.jl")
"""

#-----------Main Script----------#
struct TradeActionOut
    index_in::Int
    price_in::Float64
    amt::Int
    index_out::Int
    price_out::Float64
    diff::Float64
end

struct TradeActionIn
    index_in::Int
    price_in::Float64
    amt::Int
end

struct BacktestResults
    calculated_returns::Float64
    tradesin::Array{TradeActionIn}
    tradesout::Array{TradeActionOut}
end

struct TradeInputResults
    returns::BacktestResults
end

struct EnterMarketInfo
    index::Int
    current_price::Float64
    holding::Float64
    inmarket::Float64
    data::Array{Array{Float64, 1}, 1}
end

struct ExitMarketInfo
    index::Int
    current_price::Float64
    index_in::Int
    price_in::Float64
    holding::Float64
    inmarket::Float64
    data::Array{Array{Float64, 1}, 1}
    diff::Float64
end

mutable struct Portfolio
    holding::Int
    inmarket::Int
end

function retain(item, n , close_prices, portfolio, values, tradesout, amt)
    difference = close_prices[n] - item.price_in
    to_make_exit_decision_on = ExitMarketInfo(n, close_prices[n], item.index_in, item.price_in, portfolio.holding, portfolio.inmarket, values, difference)
    if exit_market_function(to_make_exit_decision_on)
        action_out = TradeActionOut(item.index_in, item.price_in, item.amt, n, close_prices[n], difference)
        push!(tradesout, action_out)
        portfolio.holding += amt
        portfolio.inmarket -= amt
        return false
    end
    return true
end

function backtest(
    values::Array{Array{Float64, 1}, 1},
    holding::Int,
    default_amt::Int,
    enter_market_function,
    exit_market_function
)::BacktestResults

    calculated_returns = 0.0
    close_prices = first(values)
    portfolio = Portfolio(holding, 0)

    tradesin = TradeActionIn[]
    tradesout = TradeActionOut[]

    # println(close_prices)
    for n in 1:length(close_prices)
        amt = default_amt
        have_money = portfolio.holding > amt

        to_make_enter_decision_on = EnterMarketInfo(n, close_prices[n], portfolio.holding, portfolio.inmarket, values)
        if have_money && enter_market_function(to_make_enter_decision_on)
            # WE ARE GOING TO ENTER THE MARKET AT THE CURRENT PRICE
            # AND WE WILL BUY OUR DEFAULT AMOUNT
            action = TradeActionIn(n, close_prices[n], amt)
            push!(tradesin, action)
            portfolio.holding -= amt
            portfolio.inmarket += amt
        end
        
        filter!(item -> retain(item, n ,close_prices, portfolio, values, tradesout, amt), tradesin)
    end

    # add up all the diffs for a scoring metric
    for trade in tradesout
        calculated_returns += trade.diff
    end

    BacktestResults(calculated_returns, tradesin, tradesout)
end


#----------------------Example Code-------------------------------#
using BenchmarkTools
mydata = [
           [1.0, 5.3, 0.5, 5.3, 1.0, 5.3, 1.0],
           [0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0],
       ]

function enter_market_function(market_info)
# if second row is above or equal to the limit we care about
    if market_info.data[2][market_info.index] >= 0.5 
        return true
    end
    return false
end

function exit_market_function(market_info)
    # if trade in for certain time
    if market_info.index - market_info.index_in >= 2 
        return true
    end
    return false
end

returns = backtest(
               mydata,
               100,
               5,
               enter_market_function,
               exit_market_function,
           )
@btime backtest(
    mydata,
    100,
    5,
    enter_market_function,
    exit_market_function,
)
# out = TradeInputResults(returns)

# println(out)
