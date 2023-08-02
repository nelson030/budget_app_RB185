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

  def find_category_spending(id)
    sql = <<~SQL
    SELECT spending.id AS purchase_id,
    spending.item_name AS item,
    spending.amount AS spending_amount,
    spending.date AS date_recorded
    FROM goals
    LEFT OUTER JOIN spending
    ON spending.category_id = goals.id
    WHERE goals.id = $1
    SQL
    result = query(sql, id)

    result.map do |tuple|
      {
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

  def delete_spending_item(id)
    sql = "DELETE FROM spending WHERE id = $1"
    query(sql, id)
  end
end