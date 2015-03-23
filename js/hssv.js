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
    , selectedSpecies = 'other'

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

hssv.controller('mainController', function($scope, $timeout, species) {
  _photos = []

  $scope.species = species.names()
  $scope.animals = []
  $scope.photos = []

  $scope.sortCriteria = 'breed'
  $scope.sortCriteriaList = ['breed', 'age']

  $scope.changeSort = function(sortBy) {
    $scope.sortCriteria = sortBy
    $scope.loadImages()
  }

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
    $timeout(function() { console.log ('timeout happened'); $scope.loadImages() }, 200);
  }

  $scope.photosSuccess = function(response) {
    $scope.photos = response.data
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

  $scope.loadImages = function() {
    var images = document.querySelectorAll('.wrapper img')
      , i = 0
      , l = images.length
      , bounds
      , image
      , containerHeight = document.querySelector('.main-wrapper').getBoundingClientRect().height

    for (i = 0; i < l; i++) {
      image = images[i]
      bounds = image.getBoundingClientRect()
      if (bounds.top < containerHeight + 500 && image.src === '')
        image.src = image.attributes.loadsrc.value
    }
  }
  species.fetch().then($scope.success)
})

hssv.directive('whenScrolled', function() {
  return function(scope, elt, attrs) {
    var scrollContainer = elt[0]
    elt.bind('scroll', function() {
      scope.$apply(attrs.whenScrolled)
    })
  }
})
