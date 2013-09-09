MediaCriticServer::Application.routes.draw do
  namespace :api do
    get 'lookup/:id' => 'games#lookup'
    get 'search' => 'games#search'
    get 'retrieve' => 'games#retrieve'
    get 'games/:id/comments/:type' => 'comments#list'
  end
end
