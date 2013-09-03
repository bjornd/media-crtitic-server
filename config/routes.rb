MediaCriticServer::Application.routes.draw do
  get 'api/lookup/:id' => 'api#lookup'
  get 'api/search/:query' => 'api#search'
end
