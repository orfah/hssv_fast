require 'typhoeus'
require 'nokogiri'
require 'digest'
require 'json'
require 'pp'

module HSSV
  module Helpers
    ANIMAL_LINK_REGEX = Regexp.new /animalid=(\d+)/
    IMAGE_REGEX = Regexp.new /\/([\d\w_-]+\.jpg)/

    def self.animal_id(link)
      matches = link.match(ANIMAL_LINK_REGEX)
      matches.nil? ? '' : matches[1]
    end

    def self.image_name(img_href)
      matches = img_href.match IMAGE_REGEX
      matches.nil? ? '' : matches[1]
    end
  end

  class Spider
    URL_BASE = 'https://adopt.hssvmil.org'
    SEARCH_URL = '/search/searchResults.asp?searchType=4&animalType='
    ANIMAL_URL = '/animal/animalDetails.asp?statusid=3&animalid='
    CACHE_BASE_PATH = '/dropbox'
    ANIMAL_SPECIES = {
      cat: '2,15',
      dog: '3,16',
      rabbit: 86,
      other: 87
    }

    def initialize(options={})
      @verbose = true# if options[:verbose]
      @animals = {}
    end

    def self.run(species_list=[], options={})
      Dir.mkdir CACHE_BASE_PATH unless File.exists? CACHE_BASE_PATH
      runner = self.new
      species_list = ANIMAL_SPECIES.values() if species_list.empty?
      species_list.each {|species| runner.fetch_species(species, options) }
    end

    def verbose(value=nil)
      @verbose = value unless value.nil?
      @verbose
    end

    def self.species_cache_path(species)
      "#{CACHE_BASE_PATH}/species_#{species}.json"
    end

    def self.animal_cache_path(animal_id)
      "#{CACHE_BASE_PATH}/animal_#{animal_id}"
    end

    def self.search_cache_path(animal_type, page)
      "#{CACHE_BASE_PATH}/species_#{animal_type}_page_#{page}"
    end

    def self.search_cache_hash(animal_type, page)
      path = self.search_cache_path animal_type, page
      File.exist?(path) ? File.read(path) : ''
    end

    def self.cache_path(id)
      CACHE_BASE_PATH + id.to_s
    end

    def img_cache_path(animal_id, img_name)
      "#{animal_cache_path(animal_id)}/#{img_name}"
    end

    def self.cached_hash(id)
      path = cache_path id
      File.exist?(path) ? File.read(path) : ''
    end

    def animal_url(animal_id)
      URL_BASE + ANIMAL_URL + animal_id.to_s
    end

    def image_url(img)
      URL_BASE + img
    end

    def cache_img(img, path)
      File.open(path, 'wb') { |f| f << img }
    end

    def cache_species_animals(species)
      if @animals[species]
        path = species_cache_path species
        File.open(path, 'w') { |f| f << @animals[species].to_json }
      end
    end

    def search_url
      URL_BASE + SEARCH_URL
    end

    def method_missing(method_name, *args, &block)
      if method_name.to_s.match(/get_(\w)/)
        # assume species name is a plural
        animal = method_name.to_s.replace('get_', '').chop
        fetch_species ANIMAL_SPECIES[animal] if ANIMAL_SPECIES[animal]
      elsif self.class.respond_to? method_name
        self.class.send method_name, *args
      else
        puts "method_missing #{method_name}"
      end
    end

    def fetch_animals(animals)
      animals.each { |animal| fetch_animal animal }
    end

    def fetch_animal(animal_id, options={})
      url = animal_url animal_id

      unless self.class.cached_hash(animal_id) or options[:force]
        response = Typhoeus::get url
        process_animal_page response.body, animal_id, options
      end        
    end

    ###
    # Fetch a class of animal, as defined in ANIMAL_SPECIES.
    # Returns an array of the animal ids.
    #
    # Options may contain:
    #  - deep_refresh: Refresh each animal on the search page.
    #
    # method_missing convenience api: 
    # allows you to call "get_dogs", "get_cats", "get_rabbits" and "get_others"
    ###
    def fetch_species(species, options={})
      puts "fetching species #{species}"
      @animals[species] ||= []
      url = search_url + species.to_s
      puts url
      response = Typhoeus::get(url)
      animals = []

      if response.success?
        html = Nokogiri::HTML response.body
        page_links = html.css('a.SearchResultsPageLink')
        page_links = page_links.collect { |p| p['href'] }
        page_links << url
        page_links.each {|p| puts p }

        fetch_search_pages species, page_links
        fetch_animals @animals[species]
      elsif options[:strict]
        raise Error "Species fetch for #{species} failed."
      end

      animals
    end

    def fetch_search_pages(species, page_links, options={})
      processed_pages = {}
      hydra = Typhoeus::Hydra.new

      page_links.each_with_index do |link, i|
        page_link = link
        page_link = URL_BASE + link unless page_link.start_with? 'http'
        unless processed_pages[page_link]
          puts "fetching species page #{i}: #{page_link}"# if verbose

          req = Typhoeus::Request.new page_link
          req.on_complete do |res| 
            animals = process_search_page res.body, i
            @animals[species] += animals
          end
          hydra.queue req

        end
        processed_pages[page_link] = true
      end
      hydra.run

      cache_species_animals species
  end

    def fetch_animals(animals, options={})
      hydra = Typhoeus::Hydra.new
      animals.each do |animal_data|
        animal_id = animal_data[:animal_id]
        if not File.exists? animal_cache_path(animal_id) or options[:force]
          puts "fetching animal page #{animal_url animal_id}" #if verbose
          req = Typhoeus::Request.new(animal_url(animal_id), followlocation: true)
          req.on_complete do |res| 
            process_animal_page res.body, animal_data
          end
          hydra.queue req
        end
      end

      hydra.run
    end

    def process_animal_page(page_str, animal_data, options={})
      animal_id = animal_data[:animal_id]
      path = animal_cache_path(animal_id)
      puts "making path #{path}"
      Dir.mkdir path unless File.exists? path

      hydra = Typhoeus::Hydra.new
      html = Nokogiri::HTML page_str
      images = html.css('.fancyBoxGroup').collect {|i| i['href']}

      images.collect! do |img|
        img_name = Helpers.image_name(img)
        img_path = img_cache_path animal_id, img_name
        puts "fetching image #{img} #{img_path}" if verbose
        req = Typhoeus::Request.new image_url(img)
        req.on_complete {|res| cache_img res.body, img_path }
        hydra.queue req
        img_name
      end
      hydra.run

      File.open(path + '/images.json', 'w') {|f| f << images.to_json }
     end

    def process_search_page(page_str, page_details, options={})
      html = Nokogiri::HTML page_str
      animals = html
        .css('.search-results-table .searchResultsCell .pic-wrap')
        .collect {|animal_node| animal_data animal_node }.compact
    end

    def animal_data(animal_node)
      metadata = animal_node.css('.hovertext')
        .children
        .reject  { |n| n.name == 'br' }
        .collect { |n| n.text.strip }

      (name, age, breed) = metadata

      # do a little dance around wonky data
      if breed.to_s.empty?
        breed = age
        age = ''
      end
      unless age.empty?
        age = age.split[0].sub('Mths', ' month').sub('Yrs', ' year')
        age += 's' if age.match(/(\d+)/)[1].to_i > 1
      end

      link = animal_node.css('a').first()
      unless link.nil?
        link = link['href']
        animal_id = Helpers.animal_id(link)
        {
          age: age,
          name: name,
          breed: breed,
          animal_id: animal_id
        }
      end
    end
  end
end

species = ARGV[0].nil? ? [] : JSON.parse(ARGV[0])
options = ARGV[1].nil? ? {} : JSON.parse(ARGV[1])

HSSV::Spider.run(species, options)
