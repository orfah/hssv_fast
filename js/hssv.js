hssv = angular.module('Hssv', [])

hssv.factory('species', function($http) {
  var factory = {}
    , urlBase = 'https://dl.dropboxusercontent.com/u/227528123/hssv/'
    , animalListUrl = function(speciesId) {
        return urlBase + 'species_' + speciesId + '.json'
      }
    , animalImagesUrl = function(animalId) {
        return urlBase + 'animal_' + animalId + '/images.json'
      }
    , selectedSpecies = 'dog'

  factory.mapping = {
      // kittens are 15
      cat: '2,15'
      // puppies are 16
    , dog: '3,16'
    , rabbit: 86
    , other: 87
  }

  factory.names = function() {
    var speciesNames = []
      , name

    for (name in this.mapping) {
      speciesNames.push(name)
    }
    return speciesNames
  }

  factory.fetch = function() {
    return $http.get(
      animalListUrl(this.mapping[selectedSpecies])
    )
  }

  factory.fetchAnimalImages = function(animalId) {
    return $http.get(animalImagesUrl(animalId))
  }

  factory.setSpecies = function(speciesName) {
    selectedSpecies = speciesName
    // chainable
    return factory
  }

  factory.selected = function() {
    return selectedSpecies
  }

  return factory
} )

hssv.controller('mainController', function($scope, species) {
  $scope.species = species.names()
  $scope.animals = []
  $scope.photos = []

  $scope.changeSpecies = function(speciesName) {
    species.setSpecies(speciesName)
      .fetch()
      .then($scope.success)
  }
  $scope.selected = function(speciesName) {
    return species.selected() === speciesName
  }

  $scope.success = function(response) {
    $scope.animals = response.data
  }

  $scope.photosSuccess = function(response) {
    photos = response.data
    for (i in photos) {
      photo = photos[i].split('/')
      $scope.photos.push(photo[photo.length - 1])
    }
  }

  $scope.selectedAnimal = false
  $scope.selectedPhoto = false

  $scope.deselectAnimal = function() {
    $scope.photos = []
    $scope.selectedAnimal = false
    $scope.selectedPhoto = false
  }

  $scope.selectAnimal = function(animal) {
    $scope.selectedAnimal = animal
    $scope.selectedPhoto = $scope.selectedAnimal.animal_id + '.jpg'
    species.fetchAnimalImages(animal.animal_id)
      .then($scope.photosSuccess)
  }

  $scope.selectPhoto = function(photo) {
    $scope.selectedPhoto = photo
  }

  species.fetch().then($scope.success)
})
