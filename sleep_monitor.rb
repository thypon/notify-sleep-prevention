#!/usr/bin/env ruby

require 'bundler/setup'
require 'json'
require 'set'
require 'terminal-notifier'

class SleepMonitor
  NOTIFICATION_ID = "com.sleepmonitor.prevent-sleep"
  
  # System services to filter out by default
  DEFAULT_FILTERED_SERVICES = [
    'powerd',                   # System power management
    'CloudTelemetryService',    # macOS telemetry service
    'runningboardd',           # Process lifecycle daemon
    'coreaudiod',              # Core Audio daemon
    'sharingd',                # File sharing daemon
    'useractivityd',           # User activity tracking daemon
    'cloudd',                  # iCloud sync daemon
    'appstoreagent',           # App Store background agent
    'AddressBookSourceSync',   # Contacts sync service
    'bluetoothd'               # Bluetooth daemon
  ].freeze
  
  def initialize(filter_system_services: true)
    @current_preventing_apps = Set.new
    @notification_active = false
    @filter_system_services = filter_system_services
    @filtered_services = filter_system_services ? DEFAULT_FILTERED_SERVICES : ['powerd']
  end

  def run
    puts "Starting sleep prevention monitor..."
    
    loop do
      begin
        preventing_apps = get_sleep_preventing_apps
        
        if preventing_apps.any?
          handle_apps_preventing_sleep(preventing_apps)
        else
          handle_no_apps_preventing_sleep
        end
        
        sleep 5
      rescue StandardError => e
        puts "Error: #{e.message}"
        sleep 5
      end
    end
  end

  def test_notifications
    puts "Testing notification add and removal..."
    
    # Send test notification
    puts "Sending test notification..."
    TerminalNotifier.notify("This is a test notification", 
      title: "Test Alert",
      subtitle: "Testing notification system",
      group: NOTIFICATION_ID
    )
    
    puts "Notification sent. Waiting 5 seconds..."
    sleep 5
    
    # Remove test notification
    puts "Removing notification..."
    remove_notification
    
    puts "Notification removal attempted. Test complete."
  end

  private

  def get_sleep_preventing_apps
    output = `pmset -g assertions`
    apps = []
    
    output.each_line do |line|
      if line.match(/pid (\d+)\(([^)]+)\):.*PreventUserIdleSystemSleep.*named: "([^"]+)"/)
        pid = $1
        process_name = $2
        assertion_name = $3
        
        next if @filtered_services.include?(process_name)
        
        apps << {
          pid: pid,
          process: process_name,
          assertion: assertion_name
        }
      end
    end
    
    apps
  end

  def handle_apps_preventing_sleep(apps)
    app_names = apps.map { |app| app[:process] }.to_set
    
    if app_names != @current_preventing_apps || !@notification_active
      @current_preventing_apps = app_names
      send_notification(apps)
      @notification_active = true
    end
  end

  def handle_no_apps_preventing_sleep
    if @notification_active
      remove_notification
      @current_preventing_apps.clear
      @notification_active = false
      puts "No apps preventing sleep - notification removed"
    end
  end

  def send_notification(apps)
    app_list = apps.map { |app| "• #{app[:process]}" }.join("\n")
    subtitle = apps.length == 1 ? "1 app preventing sleep" : "#{apps.length} apps preventing sleep"
    
    # Remove existing notification first
    remove_notification
    
    # Send new notification
    TerminalNotifier.notify(app_list, 
      title: "Sleep Prevention Alert",
      subtitle: subtitle,
      group: NOTIFICATION_ID
    )
    
    puts "Notification sent: #{apps.map { |app| app[:process] }.join(', ')}"
  end

  def remove_notification
    # Remove notification by group ID using the gem
    TerminalNotifier.remove(NOTIFICATION_ID)
  end
end

if __FILE__ == $0
  # Check for command line arguments
  if ARGV.include?('--test')
    puts "Running notification test..."
    monitor = SleepMonitor.new
    monitor.test_notifications
    exit 0
  end
  
  filter_system_services = !ARGV.include?('--no-filter')
  
  puts "System service filtering: #{filter_system_services ? 'enabled' : 'disabled'}"
  monitor = SleepMonitor.new(filter_system_services: filter_system_services)
  
  # Handle Ctrl+C gracefully
  trap("INT") do
    puts "\nShutting down sleep monitor..."
    exit 0
  end
  
  monitor.run
end