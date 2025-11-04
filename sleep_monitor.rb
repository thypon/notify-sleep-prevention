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

  # Programs that should never be auto-killed
  NEVER_KILL = [
    'caffeinate',              # User-initiated sleep prevention
    'appleh13camerad'          # Camera daemon
  ].freeze
  
  def initialize(filter_system_services: true, auto_kill: false, auto_kill_threshold: 300)
    @current_preventing_apps = Set.new
    @notification_active = false
    @filter_system_services = filter_system_services
    @filtered_services = filter_system_services ? DEFAULT_FILTERED_SERVICES : ['powerd']
    @auto_kill = auto_kill
    @auto_kill_threshold = auto_kill_threshold # in seconds (default: 5 minutes)
    @app_start_times = {} # Track when each app started preventing sleep
    @last_notification_content = nil # Track last notification to avoid unnecessary updates
    @original_low_power_mode = get_low_power_mode_state # Store original state
    @low_power_mode_disabled = false # Track if we disabled it
    @sudo_warning_shown = false # Track if we've shown the sudo warning
  end

  def run
    puts "Starting sleep prevention monitor..."
    puts "Auto-kill: #{@auto_kill ? "enabled (threshold: #{@auto_kill_threshold / 60} minutes)" : "disabled"}"
    puts "Low power mode: #{@original_low_power_mode == 1 ? "enabled" : "disabled"} (will be disabled when apps prevent sleep)"

    loop do
      begin
        preventing_apps = get_sleep_preventing_apps

        if preventing_apps.any?
          handle_apps_preventing_sleep(preventing_apps)
          check_and_kill_long_running_apps(preventing_apps) if @auto_kill
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

  def get_low_power_mode_state
    output = `pmset -g | grep lowpowermode`
    # Extract the value (0 or 1) from the output
    match = output.match(/lowpowermode\s+(\d+)/)
    match ? match[1].to_i : nil
  end

  def set_low_power_mode(enabled)
    value = enabled ? 1 : 0
    success = system("sudo -n pmset -a lowpowermode #{value} 2>/dev/null")

    if !success && !@sudo_warning_shown
      puts "Warning: Unable to change low power mode (sudo access required)"
      puts "To enable this feature, configure passwordless sudo for pmset:"
      puts "  sudo visudo -f /etc/sudoers.d/pmset"
      puts "  Add: #{ENV['USER']} ALL=(ALL) NOPASSWD: /usr/bin/pmset"
      @sudo_warning_shown = true
    end

    success
  end

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
    current_time = Time.now

    # Disable low power mode if not already disabled and it was originally enabled
    if !@low_power_mode_disabled && @original_low_power_mode == 1
      puts "Disabling low power mode to speed up task completion..."
      set_low_power_mode(false)
      @low_power_mode_disabled = true
    end

    # Track new apps
    app_names.each do |app_name|
      unless @app_start_times.key?(app_name)
        @app_start_times[app_name] = current_time
        puts "Started tracking: #{app_name} at #{current_time.strftime('%H:%M:%S')}"
      end
    end

    # Remove apps that are no longer preventing sleep
    @app_start_times.keys.each do |tracked_app|
      unless app_names.include?(tracked_app)
        @app_start_times.delete(tracked_app)
        puts "Stopped tracking: #{tracked_app}"
      end
    end

    # Always send notification to update the runtime display
    if app_names != @current_preventing_apps || !@notification_active
      @current_preventing_apps = app_names
      @notification_active = true
    end

    # Update notification with current runtime
    send_notification(apps)
  end

  def handle_no_apps_preventing_sleep
    if @notification_active
      remove_notification
      @current_preventing_apps.clear
      @app_start_times.clear
      @notification_active = false
      @last_notification_content = nil

      # Restore low power mode to original state if we disabled it
      if @low_power_mode_disabled && @original_low_power_mode == 1
        puts "Restoring low power mode to original state..."
        set_low_power_mode(true)
        @low_power_mode_disabled = false
      end

      puts "No apps preventing sleep - notification removed"
    end
  end

  def check_and_kill_long_running_apps(apps)
    current_time = Time.now

    apps.each do |app|
      process_name = app[:process]
      pid = app[:pid]

      next unless @app_start_times.key?(process_name)

      # Skip programs that should never be killed
      if NEVER_KILL.include?(process_name)
        puts "Skipping #{process_name} (protected from auto-kill)"
        next
      end

      elapsed_time = current_time - @app_start_times[process_name]

      if elapsed_time >= @auto_kill_threshold
        minutes_running = (elapsed_time / 60).round(1)
        puts "Killing #{process_name} (PID: #{pid}) - running for #{minutes_running} minutes"

        begin
          Process.kill("TERM", pid.to_i)
          @app_start_times.delete(process_name)
          puts "Successfully sent TERM signal to #{process_name}"
        rescue Errno::ESRCH
          puts "Process #{process_name} (PID: #{pid}) no longer exists"
          @app_start_times.delete(process_name)
        rescue Errno::EPERM
          puts "Permission denied to kill #{process_name} (PID: #{pid})"
        rescue StandardError => e
          puts "Error killing #{process_name}: #{e.message}"
        end
      end
    end
  end

  def send_notification(apps)
    current_time = Time.now
    app_list = apps.map do |app|
      process_name = app[:process]
      if @app_start_times.key?(process_name)
        elapsed_seconds = current_time - @app_start_times[process_name]
        minutes = (elapsed_seconds / 60).to_i
        "• #{process_name} (#{minutes}m)"
      else
        "• #{process_name}"
      end
    end.join("\n")

    subtitle = apps.length == 1 ? "1 app preventing sleep" : "#{apps.length} apps preventing sleep"
    notification_content = "#{subtitle}\n#{app_list}"

    # Only update notification if content has changed
    if notification_content != @last_notification_content
      # Remove existing notification first
      remove_notification

      # Send new notification
      TerminalNotifier.notify(app_list,
        title: "Sleep Prevention Alert",
        subtitle: subtitle,
        group: NOTIFICATION_ID
      )

      @last_notification_content = notification_content
      puts "Notification sent: #{apps.map { |app| app[:process] }.join(', ')}"
    end
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
  auto_kill = ARGV.include?('--auto-kill')

  # Parse threshold if provided (in minutes)
  threshold_seconds = 300 # default: 5 minutes
  threshold_arg = ARGV.find { |arg| arg.start_with?('--threshold=') }
  if threshold_arg
    threshold_minutes = threshold_arg.split('=')[1].to_i
    threshold_seconds = threshold_minutes * 60
  end

  puts "System service filtering: #{filter_system_services ? 'enabled' : 'disabled'}"
  monitor = SleepMonitor.new(
    filter_system_services: filter_system_services,
    auto_kill: auto_kill,
    auto_kill_threshold: threshold_seconds
  )

  # Handle Ctrl+C gracefully
  trap("INT") do
    puts "\nShutting down sleep monitor..."
    exit 0
  end

  monitor.run
end