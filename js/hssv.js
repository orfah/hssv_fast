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
      cat: 2
    , dog: 3
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

  factory.setSpecies = function(speciesName) {
    selectedSpecies = speciesName
    // chainable
    return factory
  }

  return factory
} )

hssv.controller('mainController', function($scope, species) {
  $scope.species = species.names()
  $scope.animals = []

  $scope.changeSpecies = function(speciesName) {
    species.setSpecies(speciesName)
      .fetch()
      .then($scope.success)
  }

  $scope.success = function(response) {
    $scope.animals = response.data
  }

  species.fetch().then($scope.success)
})
