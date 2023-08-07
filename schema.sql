CREATE TABLE goals (
id serial PRIMARY KEY,
category text NOT NULL UNIQUE,
amount numeric(6,2) NOT NULL
)
;

CREATE TABLE spending (
id serial PRIMARY KEY,
item_name text NOT NULL,
amount numeric(7,2) NOT NULL,
category_id integer NOT NULL REFERENCES goals (id) ON DELETE CASCADE,
"date" date NOT NULL DEFAULT (CURRENT_TIMESTAMP)
)
;