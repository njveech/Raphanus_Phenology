# EVE Scholars RStudio Practice Day 1
# Natalie Veech
# June 30, 2025

# Load Swirl Package
#install.packages("swirl")
library(swirl)

# open swirl
swirl()

#play() to temporarily exit swirl and mess arround, type nxt() to get back to lesson


# Operating Swirl:
# You can exit swirl and return to the R prompt (>) at any time by pressing the
# | Esc key. If you are already at the prompt, type bye() to exit and save your
# | progress. When you exit properly, you'll see a short message letting you know
# | you've done so.
# 
# | When you are at the R prompt (>):
#   | -- Typing skip() allows you to skip the current question.
# | -- Typing play() lets you experiment with R on your own; swirl will ignore
# | what you do...
# | -- UNTIL you type nxt() which will regain swirl's attention.
# | -- Typing bye() causes swirl to exit. Your progress will be saved.
# | -- Typing main() returns you to swirl's main menu.
# | -- Typing info() displays these options again.

# NOTE: command-shift-c comments everything out :)

# NOTE: option, select longways to insert something else at beginning

# basic calculation example:
#3 + 4  

# ?"command" provides help page for specific command

#NOTES FROM RSWIRL CH1: BASIC BUILDING BLOCKS---------------------------------

# If at any point you'd like more information on a particular topic related to
# R, you can type help.start() at the prompt, which will open a menu of
# resources (either within RStudio or your default web browser, depending on
# your setup). Alternatively, a simple web search often yields the answer you're
# looking for.

# " variable <- value " assigns value to variable

#The easiest way to create a vector is with the c() function, which stands for
# 'concatenate' or 'combine'. To create a vector containing the numbers 1.1, 9,
# and 3.14, type c(1.1, 9, 3.14). Try it now and store the result in a variable
# called z

#To see all variables, ls() ; 
#To remove/clear variables in workspace rm(list=ls())

#"recycling" vector means vector gets repeated to be length of longer 
#vector i.e. c(1,2,3,4) + c(0,10) becomes [1,12,3,14] b/c vector 2 recycled to 
# look like [0, 10, 0, 10]

#up arrow cycles through previous commands

#NOTES FROM RSWIRL CH2: WORKSPACE AND FILES------------------------------------

#getwd() says what directory working in

#dir() OR list.files() lists all files in directory

#args() shows arguments a function can do

# "name" to name something new/ list any name

#Other relevant & self explanatory functions: dir.create(), setwd(), 
#file.create(), file.exists(), file.rename(), file.copy(), file.path() 

# $mode following command parenthesis gathers specific items

#when changing name, format is "old", "new" ; comma represents "to" command

#NOTES FROM R SWIRL CH 3: SEQUENCES OF NUMBERS---------------------------------

#  number : number gives sequence of numbers but basic

# seq( number, number, by=factor of increase) is format to get a sequence of 
#numbers that increases by something other than 1 OR can do length= number to 
#get certain amt of numbers in a seq 

#seq_along() gives sequence with same length as given vector/list

# rep() = replicate formatted as (whats repeated, times=desired # of reps) ; 
# each can also be used in place of times as desired

#NOTES FROM RSWIRL CH 4: VECTORS-----------------------------------------------
  
# To index vector(get certain place value), use square brackets


# atomic vector(numeric, logical, character, integer, complex)
# = 1 data type, list=can be multiple data types

#A|B is union aka A or B, A&B is intersection, !A is inequality aka True when A is false

#"" distinguishes character objects

#paste() can be used to collapse elements of a character vector (i.e get rid of)
#parenthesis using (variable, collapse = " ") ORRRRR can be used to join 2 
# character vectors of length 1 via paste("Vect1", "Vect2", sep = " ")

#NOTES FROM RSWIRL CH 5: MISSING VALUES-----------------------------------------

#NA= not available or missing

# is.na() will tell whether elements of vectors are NA

# True=1 and False=0

#NaN translates to "not a number", like with 0/0 or Inf-Inf

#NOTES FROM RSWIRL CH 6: SUBSETTING VECTORS-------------------------------------

#if you want certain vector elements, place index vector in square brackets 
#after vector name like vectorname[first:end]

#Reminder : "!" exclamation points give negative version of logic expression

# R uses one-based indexing where first vector element is element 1 

#x[c(-number,-number)] is a format used to provide all the elements in a vector
# "x" EXCEPT the two numbers with negative signs OR putting the neg sign in front
#of the c works too. This is called NEGATIVE INTEGER INDEX VECTORS

#identical(thing1, thing2) will tell you if two arguments are identical via T/F

#NOTES FROM RSWIRL CH7: MATRICES AND DATA FRAMES-------------------------------

#matrices= single data class; atomic vector w/ dimensions
#data frames= many data classes

#don't need "c()" to make vector if using #:#

#dim() sets (also using c function) or prints dimensions of object

#attributes() function can print dimensions too

# dimensions are rows, columns

#cbind() combines columns, but leaves matrix with character strings (all in 
#quotations) b/c implicit coercion, since matrix cant be numbers AND characters

#data.frame() function store multiple data types as object class "data.frame"

#colnames() sets a vector as the column names of specified data frame

#NOTES FROM RSWIRL CH8: LOGIC--------------------------------------------------

# logical values=boolean values: TRUE, FALSE; can be grouped in parenthesis

# == is the equality operator

# Inequality operators are logical: <, >, <=, >=

#!= is the not equals operator

#! (NOT operator) at beginning of commands makes True, false and false, true

# AND operators are: & and &&; if both sides are TRUE, entire thing is TRUE..but
#if both sides are false or one is true and other false, whole thing is false

# & can be applied across values in a vector

# OR operators are: | which evaluates across vector or || only evaluates
#first vector member; TRUE if left or right is TRUE or both are TRUE. 
# FALSE< if both left and right aren't true

#isTRUE() operator tells if something is or isn't true

#xor() function is exclusive OR. Only returns TRUE if one arg is true and other false

#which() function takes log vectors as arg, returns indices that are true

#any() function returns TRUE if 1 or more elements in vector are true

#all() function returns TRUE is every element in vector is true

#NOTES FROM RSWIRL CH9: FUNCTIONS------------------------------------------------

#functions are small pieces of reusable code, like other objects

#name of function followed by parenthesis; return value or manipulate data

#mean() gives average... duh

#arguments are inputs to functions, providing arguments=passing arguments

#To see source code for function, type name w/o parenthesis or arguments

#when typing functions, assign name with arrow, use function() command, put
#arguments in parenthesis, in swirly brackets, define what want function to do
#with arguments

#if explicitly designating arguments, order doesn't matter; can partially match
#arguments

#args(functionname) lets you see a function's arguments

#... means infinite amount of arguments can be passed to function

#paste() can take any number of strings as arguments and will return all strings
#combined into one string

#all arguments after ellipses must have default values

#NOTES FROM RSWIRL CH10: LAPPLY AND SAPPLY-------------------------------------

#sapply and lapply are most important of the apply loop functions

#implements Split-Apply-Combine strategy for data analysis:
#split into smaller pieces, apply function to each piece, combine results

#to find out class of individual columns, need loop functions

#lapply: list is input, applies function to each element, returns list of same
#length

#as.character can turn list of characters into character vector

#sapply calls lapply behind scenes, then SIMPLIFIES reuslts: into character vector
#if all element length=1, or if all element vector of same length >1, returns matrix

#NOTES FROM RSWIRL CH11: VAPPLY AND TAPPLY---------------------------------------

#sapply guesses correct format of result, vapply lets you specify format 
#explicitly; vapply safer than sapply for writing own functions

#if format doesnt match results, vapply gives error message, good for preventing
#more of a hassle when coding

#vapply outline: (data, function, format(numeric vector length if needed))

#tapply: split data into groups based on value of a variable, then apply 
#function to members of each group

#tapply example: applying mean function to the animate variable on flags for
#each of the 6 diff continents separately

#tapply(variable, group split, function)

#NOTES FRON RSWIRL CH12: LOOKING AT DATA----------------------------------------

#ls() lists variables in workspace

#class() tells class: i.e. data frame, matrix, character vector, list, etc.

#data frame is default class for data read into R via read.csv() and read.table()
#its rectangular with rows(observations) and columns(variables)
#you can see those dimensions w/ dim(), or just nrow() or ncol()

#Memory Space in bytes determined using object.size(data set)

#names(data set) gives character vector of column names

#head() previews top of data set, can specify # of rows by passing # as 2nd arg.
#tail() does same with back end of data set

#summary() provides info like class, mode, length, min, max, median, mean, NA's, etc.

#table(dataset$variable) displays counts for each level/value of a variable

#str() give structure of data, gives class, obs, var(name, class, preview)

#NOTES FROM RSWIRL CH13: SIMULATION---------------------------------------------

#sample(x, size, replace = FALSE, prob = NULL) where x= pos integer or vector 
#in #:# format, size=integer with number to choose, replace=whether to replace
#or not when sampling (i.e can something show up again after selected); prob 
#can assign prob weights to vector elements w/ prob= c(prob1, prob2)

#sample() can simulate probability things like rolling dice, flipping coins, etc.

#LETTERS= predefined variable in R with all 26 letters; permute=rearrange

#when size not specified, sample function permutes and rearranges/gives sample
#size equal in size to vector sampling from

#rbinom() simulates binomial(2 outcome) random variable; number of successes in
#given number of independent trials
#rbinom(#observations, size = #trials, prob = success)

#prob distributions in R have: 1) r*** function for random, 2) d*** function 
#for density, 3) p*** function for probability, 4) q*** function for quantile

#rnorm, pnorm. dnorm, qnorm can all be used for standard normal distr. with
#mean=0 and sd=1 (defaults); specify n for rnorm as # observations

#rpois, dpois, qpois, ppois for poisson distribution; lambda=vector of means

#replicate(number replications, operation to rpelicate) to do a process repeatedly
#will create a matrix with columns of specified random values

#colMeans() takes mean of each column

#hist() will plot a histogram 

#there are many standard prob distributions built into R

#NOTES FROM RSWIRL CH14: DATES AND TIMES--------------------------------------

#R can be useful for data that shows change over time(time-series data)
#date is a type of class

#Dates= date class, stored as # days since 1970-01-01; 
#times= POSIXct (# seconds since 1970-01-01) and
# POSIXlt (list of seconds, minutes, hrs) classes

#Sys.Date gets current date; Sys.time() gives current time and date

#unclass() returns argument with class attribute removed; takes date from Year-
#Month-Day format to # days since 1970-01-01

# dates before 1970-01-01 when unclassed, listed as neg numbers

#By default, Sys.time() returns an object of class POSIXct, but we can coerce
# the result to POSIXlt with as.POSIXlt(Sys.time())

#weekdays() returns day of week from a date or time object
#months()  returns month from date or time object
#quarters() returns quarter from date or time object

#strptime() converts character vector inputs of no specific format to POSIXlt
#strptime(variable to change, %B %d, %Y %H:%M)

#can use arithmetic and comparison operations on dates and times

#difftime() function lets you specify units when finding difference b/t 2 times

#NOTES FROM RSWIRL CH 15: BASE GRAPHICS-----------------------------------------

#data(dataofinterest) to load in a data frame
 
#good idea to use head, tail, dim, summary to get sense of data

#plot(data set) will create a plot of a data frame based on what makes sense 
#from the info the data provides/you provide; if two columns, plots them against
#eachother, uses names of columns for axes, creates axis tick marks at rounded
#numbers and labels them, etc.(defaults from plot function)

#plot()=scatterplot specifically

#plot(x = variable, y= varaible, other details here); Other details are:
#can label axes with xlab = "name" or ylab = "name"
#main = "name" gives main title, sub = "name" gives subtitle
#col to specify color of points, xlim or ylim= limit axis scope
#pch is plotting character, changes shape of points

#fyi*** plot can pass multiple arguments/other details to adjust plot at once

#more modern packages exst for cretaing graphics, like ggplot2

#boxplot() better to pass in entire data frame as opposed to columns as inputs;
#box and whisker plot

#boxplot() takes formula argument: expression with ~ that indicates relationship
#b/t input variables

#boxplot format is: (formula = variable ~ variable, data = datawanted)


