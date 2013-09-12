MediaCriticServer::Application.routes.draw do
  namespace :api do
    get 'lookup/:id' => 'games#lookup'
    get 'search' => 'games#search'
    get 'retrieve' => 'games#retrieve'
    get 'games/:id/reviews/:type' => 'reviews#list'
    get 'games/:id/offers/amazon' => 'offers#list_amazon'
    get 'games/:id/offers/ebay' => 'offers#list_ebay'
  end
end
