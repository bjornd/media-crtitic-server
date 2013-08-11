MediaCriticServer::Application.routes.draw do
  get 'api/lookup/:id' => 'api#lookup'
end
