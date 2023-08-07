require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "database_persistence"

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

helpers do
  def all_goals
    @storage.all_goals
  end
  
  def purchase_dates(spending_info)
    dates_arr = []
    spending_info.each do |tuple|
      date = convert_str_to_date(tuple[:date_recorded])
      date = first_day_of_month(date)
      dates_arr << date if month_and_year_unique?(date, dates_arr)
    end

    dates_arr
  end
  
  def last_day_of_month(date)
    date.next_month.prev_day
  end
  
  def first_day_of_month(date)
    Date.new(date.year, date.month, 1)
  end
  
  def num_to_month(n)
    case n
    when 1
      "January"
    when 2
      "February"
    when 3
      "March"
    when 4
      "April"
    when 5
      "May"
    when 6
      "June"
    when 7
      "July"
    when 8
      "August"
    when 9
      "September"
    when 10
      "October"
    when 11
      "November"
    when 12
      "December"
    else
      ""
    end
  end
  
  def convert_str_to_date(str_date)
    DateTime.parse(str_date).to_date
  end
  
  def sum_purchases(spending_arr)
    sum = 0

    spending_arr.each do |tuple|
      sum += tuple[:spending_amount].to_f
    end

    sum
  end
  
  def format_float_number(num)
    s = num.to_s
    dec_counter = 0
    dec = false
    
    s.each_char do |char|
      if char == "." || dec == true
        dec = true
        dec_counter += 1
      end
    end
    
    s = add_zero_to_float(s) if dec_counter < 3
    
    s
  end
  
  def unique_months(dates_arr)
    unique_arr = []
  
    dates_arr.map do |date_str|
      date = first_day_of_month(convert_str_to_date(date_str))
      unique_arr << date unless unique_arr.include?(date)
    end
    
    unique_arr
  end
  
  def zero_if_nil(num_str)
    if num_str == nil
      "0.00"
    else
      num_str
    end
  end

  private
  
  def add_zero_to_float(str_num)
    str_num += "0"
  end

  def month_and_year_unique?(date, arr)
    check_arr = arr.select do |d|
      d.year == date.year && d.month == date.month
    end
    
    if check_arr == []
      return true
    else
      return false
    end
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  erb :home, layout: :layout
end

get "/spending" do
  erb :spending, layout: :layout
end

get "/spending/:category_id/:date" do
  if params[:date] == "current"
    @date = Date.today
  else
    @date = first_day_of_month(convert_str_to_date(params[:date]))
  end
  @category_id = params[:category_id].to_i

  day_1 = first_day_of_month(@date)
  day_last = last_day_of_month(day_1)

  @spending = @storage.find_category_spending(@category_id, day_1, day_last)
  
  all_dates = @storage.find_valid_dates(@category_id)
  @valid_dates = unique_months(all_dates)
  
  erb :category_spending, layout: :layout
end

post "/spending/:category_id/getdate" do
  category_id = params[:category_id].to_i
  date = params[:date]
  
  redirect "/spending/#{category_id}/#{date}"
end

post "/spending/add" do
  category_id = params[:category_chosen].to_i unless params[:category_chosen] == nil
  item_name = params[:name]
  amount = params[:amount].to_f.round(2)

  if amount >= 100000.00 || amount == nil
    session[:error] = "Invalid Amount. Must be less than 100,000.00 and a valid number."
    erb :spending
  elsif category_id == nil
    session[:error] = "Invalid. A category must be chosen."
    erb :spending
  elsif item_name == nil
    session[:error] = "Invalid. Item name is required."
    erb :spending
  else
    @storage.add_spending(item_name, amount, category_id)
    session[:success] = "Success!"
    redirect "/spending"
  end
end

post "/spending/deleteitem/:purchase_id" do
  purchase_id = params[:purchase_id].to_i
  
  # ADD CHECK STATEMENTS ??
  @storage.delete_spending_item(purchase_id)
  redirect "/spending"
end

get "/goals" do
  redirect "/goals/current"
end

get "/goals/:date" do
  if params[:date] == "current"
    @date = Date.today
  else
    @date = first_day_of_month(convert_str_to_date(params[:date]))
  end
  
  day_1 = first_day_of_month(@date)
  day_last = last_day_of_month(day_1)

  @category_data = @storage.find_all_spending_and_goals(day_1, day_last)
  
  all_dates = @storage.find_all_valid_dates

  @valid_dates = unique_months(all_dates)
  
  erb :goals, layout: :layout
end

post "/goals/getdate" do
  date = params[:date]
  
  redirect "/goals/#{date}"
end

post "/goals/addgoal" do
  category = params[:category]
  amount = params[:amount].to_f.round(2)
  
  existing_categories = all_goals.map do |tuple|
    tuple[:category]
  end
  
  if amount >= 10000.00 || amount == nil
    session[:error] = "Invalid Amount. Must be less than 10,000.00 and a valid number."
    erb :goals
  elsif existing_categories.include?(category) || category == nil
    session[:error] = "Category name must be unique and not empty. Must be less than 10,000.00."
    erb :goals
  else
    @storage.add_goal(category, amount)
    session[:success] = "Success!"
    redirect '/goals'
  end
end

post "/goals/deletegoal/:id" do
  goal_id = params[:id].to_i
  
  existing_ids = all_goals.map do |tuple|
    tuple[:id]
  end
  
  if !existing_ids.include?(goal_id)
    session[:error] = "Database error. Check with system admin."
    erb :goals
  else
    @storage.delete_goal(goal_id)
    session[:success] = "Category deleted successfully."
    redirect "/goals"
  end
end