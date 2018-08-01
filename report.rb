#!/usr/bin/env ruby

require 'octokit'
require 'csv'

class ProjectStats
  attr_reader :client, :card_data

  def initialize
    @client = initialize_client
    @card_data = initialize_cards
    @card_headings = initialize_headings
  end

  def report
    client.project_columns(project_id).each do |column|
      next if ignored_columns.include?(column[:name])

      client.column_cards(column[:id]).each do |card|
        @card_data[card[:id]] = {} unless @card_data.key?(card[:id])

        set_start_date(card[:id]) if column[:name] == ENV["DOING_COLUMN_NAME"]
        finalise_card(card) if column[:name] == ENV["DONE_COLUMN_NAME"]
        add_column_date(card[:id], column[:name])
      end
    end

    write_data
  end

  private

  def write_data
    CSV.open("card-stats.csv", "w") do |csv|
      csv << @card_headings.to_a

      @card_data.each do |id, data|
        csv << @card_headings.map do |key|
          key == "ID" ? id : (data.key?(key) ? data[key] : nil)
        end
      end
    end
  end

  def add_column_date(card_id, column)
    @card_headings << column

    return if @card_data[card_id].key?(column) && !@card_data[card_id][column].to_s.empty?

    @card_data[card_id][column] = Date.today.strftime("%d/%m/%Y")
  end

  def set_start_date(card_id)
    return if @card_data[card_id].key?("Start Date") && !@card_data[card_id]["Start Date"].to_s.empty?

    @card_data[card_id]["Start Date"] = Date.today.strftime("%d/%m/%Y")
  end

  def finalise_card(card)
    return if @card_data[card[:id]].key?("Completed Date") && !@card_data[card[:id]]["Completed Date"].to_s.empty?

    set_start_date(card[:id])

    @card_data[card[:id]].tap do |card_row|
      card_row["Sum Value"] = 1 # used for reporting in numbers
      card_row["Completed Date"] = Date.today.strftime("%d/%m/%Y")
      card_row["Cycle Time"] = (Date.parse(card_row["Completed Date"]) - Date.parse(card_row["Start Date"])).to_i

      if card[:note]
        card_row["Card"] = card[:note]
        card_row["Labels"] = "note"
      else
        repo, issue_id = card[:content_url].match(/.*\/repos\/(.*)\/issues\/(\d*)/).captures
        issue = client.issue(repo, issue_id)

        card_row["Issue"]  = "http://github.com/greensync/#{repo}/issues/#{issue_id}"
        card_row["Card"] = issue[:title]
        card_row["Labels"] = repo.split("/").last.gsub("_", "-") + " "
        card_row["Labels"] += issue[:labels].map{ |label| label[:name].gsub(" ", "-") }.join(" ")
      end
    end
  end

  def ignored_columns
    ENV["IGNORED_COLUMNS"].split(",").map(&:strip)
  end

  def project_id
    client.org_projects('greensync').find { |project| project[:name] == ENV["PROJECT_NAME"] }[:id]
  end

  def initialize_cards
    card_data = {}

    CSV.foreach("card-stats.csv", :headers => true, encoding: "UTF-8") do |row|
      card_data[row.fields[0].to_i] = Hash[row.headers[1..-1].zip(row.fields[1..-1])]
    end

    card_data
  end

  def initialize_headings
    Set.new(["ID", "Card", "Issue", "Sum Value", "Start Date", "Completed Date", "Cycle Time", "Labels"])
  end

  def initialize_client
    enable_debugging if ENV["DEBUG"] && ENV["DEBUG"] == "true"
    Octokit.auto_paginate = true

    client  = Octokit::Client.new(:access_token => ENV["GIT_ACCESS_TOKEN"])
    client.user.login

    client
  end

  def enable_debugging
    Octokit.middleware = Faraday::RackBuilder.new do |builder|
      builder.response :logger
      builder.use Octokit::Response::RaiseError
      builder.adapter Faraday.default_adapter
    end
  end
end

ProjectStats.new.report
