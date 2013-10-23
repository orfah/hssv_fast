require 'typhoeus'
require 'json'
require 'fileutils'
require 'pp'

module HSSV

  class Cleaner
    BASE_URL = "https://dl.dropboxusercontent.com/u/227528123/hssv"
    BASE_PATH = "/dropbox"

    ANIMAL_SPECIES = {
      cat: '2,15',
      dog: '3,16',
      rabbit: 86,
      other: 87
    }

    def initialize(options={})
      @verbose = options[:verbose]
    end

    def verbose
      @verbose
    end

    def fetch_animal_list(species)
      url = BASE_URL + "/species_#{species}.json"
      puts "fetching #{url}" if verbose

      response = Typhoeus::get(url)
      if response.success?
        return JSON.parse(response.body).collect {|a| a['animal_id']}
      end

      []
    end

    def fetch_animals
      animals = []
      ANIMAL_SPECIES.each_pair do |key, species|
        animals += fetch_animal_list species
      end

      animals
    end

    def clean
      all_animals = fetch_animals
      Dir.chdir(BASE_PATH)
      Dir.glob('animal_*').each do |animal_dir|
        animal_id = animal_dir.split('_')[1]
        unless all_animals.include? animal_id
          puts "deleting #{animal_dir}" if verbose
          FileUtils.rm_r animal_dir, force: true
        end
      end
    end

    def self.run(options={})
      runner = self.new options
      runner.clean
   end

  end
end

HSSV::Cleaner.run(verbose: true)