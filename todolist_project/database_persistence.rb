def create_new_list(list_name)
  sql = "INSERT INTO lists (name) VALUES ($1)"
  query(sql, list_name)
end

def delete_list(id)
  query("DELETE FROM todos WHERE list_id = $1", id)
  query("DELETE FROM lists WHERE id = $1", id)
end

def create_new_todo(list_id, todo_name)
  sql = "Insert INTO todos (list_id, name) VALUES ($1, $2)"
  query(sql, list_id, todo_name)
end

def delete_todo_from_list(list_id, todo_id)
  sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2"
  query (sql, too_id, list_id)
end

def update_todo_status(list_id, todo_id, new_status)
  sql "Update todos SET completed = $1 WHERE id = $2 and list_id ="
  query (sql, new_status, todo_id, list_id)
end