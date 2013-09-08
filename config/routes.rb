MediaCriticServer::Application.routes.draw do
  get 'api/lookup/:id' => 'api#lookup'
  get 'api/search' => 'api#search'
  get 'api/retrieve' => 'api#retrieve'
end
