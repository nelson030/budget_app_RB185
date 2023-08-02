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
      date = DateTime.parse(tuple[:date_recorded]).to_date
      dates_arr << date if month_and_year_unique?(date, dates_arr)
    end
    puts dates_arr
    dates_arr
  end
  
  private
  
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

get "/spending/:category_id" do
  category_id = params[:category_id].to_i
  @spending = @storage.find_category_spending(category_id)
  
  erb :category_spending, layout: :layout
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
  erb :goals, layout: :layout
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

get "/progress" do
  erb :progress, layout: :layout
end