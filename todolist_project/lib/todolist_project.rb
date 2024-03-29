require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do 
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

helpers do 
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def sort_lists(lists, &block)
     complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each { |list| yield list, lists.index(list)}
    complete_lists.each  { |list| yield list, lists.index(list)}
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each{ &block}
    complete_todos.each{ &block}
  end
end

class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |l| |[:id] == id }
  end

  def all_list
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_element_id(@session[:lists])
    @session[:lists] << {id: id, name: list_name, todos: []}
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list_name(id, new_name)
    list = find_list(id)
    list[:name] = new_name
  end

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    id = next_element_id(list[:todos])
    list[:todos] << { id: id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    list = find_list(list_id)
    todo = list[:todos].find { |t| t[:id] == todo_id }
    todo[:completed] = new_status
  end

  def mark_all_todos_as_completed(list_id)
    list = find_list(list_id)
    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

    private

    def next_element_id(elements)
      max = elements.map { |todo| todo[:id] }.max || 0
      max + 1
    end
  end
  
  def load_list(id)
    list = @storage.find_list(id)
    return list if list
  
    session[:error] = "The specified list was not found."
    redirect "/lists"
  end
  
# return an error message if the name is invalid. retuan nil if name is valid 
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "list name must be between 1-100 characters"
 
  elsif session[:lists].any? {|list| list[:name] == name}
    "list name must be unique"
  end
end

  def error_for_todo(name)
      if !(1..100).cover? name.size
      "todo name must be between 1-100 characters"
    end
  end

  before do 
    @storage = SessionPersistence.new(session)
  end

  get "/" do 
    redirect "/lists"
  end

  #view list of lists
  get "/lists" do 
    @lists = @storage.all_lists
    erb :lists, layout: :layout
  end

  #Render the new list form
  get "/lists/new" do 
    erb :new_list, layout: :layout
  end

  #Create a new list
post "/lists" do
  list_name = params[:list_name].strip

   error = error_for_list_name(list_name)
   if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

#view a single todo list 
get "/lists/:id" do 
  @list_id = params[:id].to_i
  @list = @load_list(@list_id)
  erb :list, layout: :layout
end

#edit a existing todo list 
get "/lists/:id/edit" do
  id = params[id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

#update an existing todo list 
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[id].to_i
  @list =load_list(id)

  error = error_for_list_name(list_name)
  if error
   session[:error] = error
   erb :edit_list, layout: :layout
 else
  @storage.update_list_name(id, list_name)
   session[:success] = "The list has been updated."
   redirect "/lists/#{id}"
 end
end

#delete a todo list 
post"/lists/:id/destroy" do
id = params[:id].to_i

@storage.delete_list(id)

session[:success] = "The list has been deleted."
if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpREQUEST"
  "/lists"
else
  redirect "/lists"
 end
end

#add a new todo to a list 
post "/lists/:list_id/todos" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error 
    session[:error] = error
    erb :list, layout: :layout
  else 
    @storage.create_new_todo(@list_id, text)

    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

#delete a todo from list 
post "/lists/:list_id/todos/:id/destroy" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @storage.delete_todo_from_list(@list_id, todo_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else 
    session[:success] = "The todo has been deleted"
    redirect "/lists/#{@list_id}"
end
end

#update the status of a todo

post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "The todo as been updated "
  redirect "/lists/#{@list_id}"
end

#mark all todos as complete
post "/lists/:id/complete_all" do 
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

 @storage.mark_all_todos_as_completed(@list_id)

   session[:success] = "all todos have been completed "
  redirect "/lists/#{@list_id}"
end
