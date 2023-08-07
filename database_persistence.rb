require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "budget")
    end
    @logger = logger
  end

  def disconnect
    @db.close
  end
  
  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    
    @db.exec_params(statement, params)
  end
  
  def all_goals
    sql = "SELECT * FROM goals"
    result = query(sql)
    
    result.map do |tuple|
      {
        id: tuple["id"].to_i,
        category: tuple["category"],
        amount: tuple["amount"]
      }
    end
  end

  def add_goal(category, amount)
    sql = "INSERT INTO goals (category, amount) VALUES ($1, $2)"
    query(sql, category, amount)
  end
  
  def delete_goal(id)
    sql = "DELETE FROM goals WHERE id = $1"
    query(sql, id)
  end

  def add_spending(name, amount, category_id)
    sql = "INSERT INTO spending (item_name, amount, category_id) VALUES ($1, $2, $3)"
    query(sql, name, amount, category_id)
  end

  def find_category_spending(id, first_day, last_day)
    sql = <<~SQL
    SELECT goals.category AS category_name,
    goals.amount AS goal_amount,
    spending.id AS purchase_id,
    spending.item_name AS item,
    spending.amount AS spending_amount,
    spending.date AS date_recorded
    FROM goals
    LEFT OUTER JOIN spending
    ON spending.category_id = goals.id
    WHERE goals.id = $1 AND
    spending.date >= $2 AND
    spending.date <= $3
    SQL
    result = query(sql, id, first_day, last_day)

    result.map do |tuple|
      {
        category_name: tuple["category_name"],
        goal_amount: tuple["goal_amount"],
        purchase_id: tuple["purchase_id"].to_i,
        item: tuple["item"],
        spending_amount: tuple["spending_amount"],
        date_recorded: tuple["date_recorded"]
      }
    end
  end
  
  # def list_purchases_for_category_with_date(id, date=Date.today)
  def find_category_spending_total(id)
    sql = <<~SQL
    SELECT SUM(spending.amount) AS total
    FROM goals
    LEFT OUTER JOIN spending
    ON spending.category_id = goals.id
    WHERE goals.id = $1
    SQL
    result = query(sql, id)

    tuple = result.first

    tuple["total"]
  end
  
  def find_valid_dates(id)
    sql = <<~SQL
    SELECT DISTINCT
    spending.date AS date_recorded
    FROM goals
    LEFT OUTER JOIN spending
    ON spending.category_id = goals.id
    WHERE goals.id = $1
    ORDER BY date_recorded DESC
    SQL
    result = query(sql, id)
    
    result.map do |tuple|
      tuple["date_recorded"]
    end
  end
  
  def find_all_valid_dates
    sql = <<~SQL
    SELECT DISTINCT
    spending.date AS date_recorded
    FROM goals
    INNER JOIN spending
    ON spending.category_id = goals.id
    ORDER BY date_recorded DESC
    SQL
    result = query(sql)
    
    result.map do |tuple|
      tuple["date_recorded"]
    end
  end

  def delete_spending_item(id)
    sql = "DELETE FROM spending WHERE id = $1"
    query(sql, id)
  end
  
  def find_all_spending_and_goals(day1, day_last)
    sql = <<~SQL
    SELECT goals.id AS goal_id,
    goals.category AS category,
    goals.amount AS goal,
    SUM(spending.amount) AS spending_total
    FROM goals
    LEFT OUTER JOIN spending
    ON goals.id = spending.category_id AND
    spending.date >= $1 AND
    spending.date <= $2
    GROUP BY goals.id
    ORDER BY category ASC
    SQL
    result = query(sql, day1, day_last)
    
    result.map do |tuple|
      spending = tuple["spending_total"]
      spending = "0.00" if spending == nil

      {
        goal_id: tuple["goal_id"],
        category: tuple["category"],
        goal: tuple["goal"],
        total_spending: spending
      }
    end
  end
end