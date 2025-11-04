# Sleep Prevention Monitor Makefile

SCRIPT_DIR := $(shell pwd)
SERVICE_NAME := com.sleepmonitor.notify-sleep-prevention
PLIST_FILE := $(HOME)/Library/LaunchAgents/$(SERVICE_NAME).plist
LOG_DIR := $(HOME)/Library/Logs

.PHONY: install install_test uninstall status help

help: ## Show this help message
	@echo "Sleep Prevention Monitor - Available commands:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install the sleep monitor as a macOS startup service
	@echo "Installing Sleep Prevention Monitor as macOS startup service..."
	@# Check if Ruby is installed
	@if ! command -v ruby >/dev/null 2>&1; then \
		echo "Error: Ruby is not installed. Please install Ruby first."; \
		exit 1; \
	fi
	@# Check if bundler is installed
	@if ! command -v bundle >/dev/null 2>&1; then \
		echo "Installing bundler..."; \
		gem install bundler --no-document; \
	fi
	@echo "Installing gems via bundler..."
	@bundle install
	@# Make the script executable
	@chmod +x $(SCRIPT_DIR)/sleep_monitor.rb
	@# Create LaunchAgent directory if it doesn't exist
	@mkdir -p $(HOME)/Library/LaunchAgents
	@mkdir -p $(LOG_DIR)
	@# Get the current Ruby and bundle paths
	@RUBY_PATH=$$(which ruby); \
	BUNDLE_PATH=$$(which bundle); \
	echo "Using Ruby: $$RUBY_PATH"; \
	echo "Using Bundle: $$BUNDLE_PATH"; \
	echo '<?xml version="1.0" encoding="UTF-8"?>' > $(PLIST_FILE); \
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(PLIST_FILE); \
	echo '<plist version="1.0">' >> $(PLIST_FILE); \
	echo '<dict>' >> $(PLIST_FILE); \
	echo '    <key>Label</key>' >> $(PLIST_FILE); \
	echo '    <string>$(SERVICE_NAME)</string>' >> $(PLIST_FILE); \
	echo '    <key>ProgramArguments</key>' >> $(PLIST_FILE); \
	echo '    <array>' >> $(PLIST_FILE); \
	echo "        <string>$$BUNDLE_PATH</string>" >> $(PLIST_FILE); \
	echo '        <string>exec</string>' >> $(PLIST_FILE); \
	echo '        <string>ruby</string>' >> $(PLIST_FILE); \
	echo '        <string>sleep_monitor.rb</string>' >> $(PLIST_FILE); \
	echo '        <string>--auto-kill</string>' >> $(PLIST_FILE); \
	echo '    </array>' >> $(PLIST_FILE); \
	echo '    <key>EnvironmentVariables</key>' >> $(PLIST_FILE); \
	echo '    <dict>' >> $(PLIST_FILE); \
	echo '        <key>PATH</key>' >> $(PLIST_FILE); \
	echo "        <string>$$(echo $$PATH)</string>" >> $(PLIST_FILE); \
	echo '        <key>HOME</key>' >> $(PLIST_FILE); \
	echo "        <string>$$HOME</string>" >> $(PLIST_FILE); \
	echo '    </dict>' >> $(PLIST_FILE); \
	echo '    <key>RunAtLoad</key>' >> $(PLIST_FILE); \
	echo '    <true/>' >> $(PLIST_FILE); \
	echo '    <key>KeepAlive</key>' >> $(PLIST_FILE); \
	echo '    <true/>' >> $(PLIST_FILE); \
	echo '    <key>StandardOutPath</key>' >> $(PLIST_FILE); \
	echo '    <string>$(LOG_DIR)/sleep-monitor.log</string>' >> $(PLIST_FILE); \
	echo '    <key>StandardErrorPath</key>' >> $(PLIST_FILE); \
	echo '    <string>$(LOG_DIR)/sleep-monitor-error.log</string>' >> $(PLIST_FILE); \
	echo '    <key>WorkingDirectory</key>' >> $(PLIST_FILE); \
	echo '    <string>$(SCRIPT_DIR)</string>' >> $(PLIST_FILE); \
	echo '</dict>' >> $(PLIST_FILE); \
	echo '</plist>' >> $(PLIST_FILE)
	@# Load and start the service
	@launchctl load $(PLIST_FILE)
	@launchctl start $(SERVICE_NAME)
	@echo "✓ Sleep Prevention Monitor has been installed and started!"
	@echo
	@echo "Service details:"
	@echo "  • Service name: $(SERVICE_NAME)"
	@echo "  • Configuration: $(PLIST_FILE)"
	@echo "  • Logs: $(LOG_DIR)/sleep-monitor.log"
	@echo "  • Error logs: $(LOG_DIR)/sleep-monitor-error.log"
	@echo
	@echo "The service will now start automatically on boot."

install_test: ## Install the sleep monitor as a test service (runs --test once)
	@echo "Installing Sleep Prevention Monitor test service..."
	@# Check if Ruby is installed
	@if ! command -v ruby >/dev/null 2>&1; then \
		echo "Error: Ruby is not installed. Please install Ruby first."; \
		exit 1; \
	fi
	@# Check if bundler is installed
	@if ! command -v bundle >/dev/null 2>&1; then \
		echo "Installing bundler..."; \
		gem install bundler --no-document; \
	fi
	@echo "Installing gems via bundler..."
	@bundle install
	@# Make the script executable
	@chmod +x $(SCRIPT_DIR)/sleep_monitor.rb
	@# Create LaunchAgent directory if it doesn't exist
	@mkdir -p $(HOME)/Library/LaunchAgents
	@mkdir -p $(LOG_DIR)
	@# Get the current Ruby and bundle paths
	@RUBY_PATH=$$(which ruby); \
	BUNDLE_PATH=$$(which bundle); \
	echo "Using Ruby: $$RUBY_PATH"; \
	echo "Using Bundle: $$BUNDLE_PATH"; \
	echo '<?xml version="1.0" encoding="UTF-8"?>' > $(PLIST_FILE); \
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(PLIST_FILE); \
	echo '<plist version="1.0">' >> $(PLIST_FILE); \
	echo '<dict>' >> $(PLIST_FILE); \
	echo '    <key>Label</key>' >> $(PLIST_FILE); \
	echo '    <string>$(SERVICE_NAME)</string>' >> $(PLIST_FILE); \
	echo '    <key>ProgramArguments</key>' >> $(PLIST_FILE); \
	echo '    <array>' >> $(PLIST_FILE); \
	echo "        <string>$$BUNDLE_PATH</string>" >> $(PLIST_FILE); \
	echo '        <string>exec</string>' >> $(PLIST_FILE); \
	echo '        <string>ruby</string>' >> $(PLIST_FILE); \
	echo '        <string>sleep_monitor.rb</string>' >> $(PLIST_FILE); \
	echo '        <string>--test</string>' >> $(PLIST_FILE); \
	echo '    </array>' >> $(PLIST_FILE); \
	echo '    <key>EnvironmentVariables</key>' >> $(PLIST_FILE); \
	echo '    <dict>' >> $(PLIST_FILE); \
	echo '        <key>PATH</key>' >> $(PLIST_FILE); \
	echo "        <string>$$(echo $$PATH)</string>" >> $(PLIST_FILE); \
	echo '        <key>HOME</key>' >> $(PLIST_FILE); \
	echo "        <string>$$HOME</string>" >> $(PLIST_FILE); \
	echo '    </dict>' >> $(PLIST_FILE); \
	echo '    <key>RunAtLoad</key>' >> $(PLIST_FILE); \
	echo '    <true/>' >> $(PLIST_FILE); \
	echo '    <key>StandardOutPath</key>' >> $(PLIST_FILE); \
	echo '    <string>$(LOG_DIR)/sleep-monitor.log</string>' >> $(PLIST_FILE); \
	echo '    <key>StandardErrorPath</key>' >> $(PLIST_FILE); \
	echo '    <string>$(LOG_DIR)/sleep-monitor-error.log</string>' >> $(PLIST_FILE); \
	echo '    <key>WorkingDirectory</key>' >> $(PLIST_FILE); \
	echo '    <string>$(SCRIPT_DIR)</string>' >> $(PLIST_FILE); \
	echo '</dict>' >> $(PLIST_FILE); \
	echo '</plist>' >> $(PLIST_FILE)
	@# Load and start the service
	@launchctl load $(PLIST_FILE)
	@launchctl start $(SERVICE_NAME)
	@echo "✓ Sleep Prevention Monitor test service has been installed and started!"
	@echo
	@echo "This will run the notification test once and exit."
	@echo "Check the logs to see the test results:"
	@echo "  • Logs: $(LOG_DIR)/sleep-monitor.log"
	@echo "  • Error logs: $(LOG_DIR)/sleep-monitor-error.log"

uninstall: ## Remove the sleep monitor service from macOS startup
	@echo "Uninstalling Sleep Prevention Monitor..."
	@# Stop the service if running
	@-launchctl stop $(SERVICE_NAME) 2>/dev/null
	@# Unload the service
	@-launchctl unload $(PLIST_FILE) 2>/dev/null
	@# Remove the plist file
	@if [ -f $(PLIST_FILE) ]; then \
		rm $(PLIST_FILE); \
		echo "✓ Removed service configuration"; \
	else \
		echo "Service configuration not found"; \
	fi
	@# Optionally remove log files
	@if [ -f $(LOG_DIR)/sleep-monitor.log ]; then \
		rm $(LOG_DIR)/sleep-monitor.log; \
		echo "✓ Removed log file"; \
	fi
	@if [ -f $(LOG_DIR)/sleep-monitor-error.log ]; then \
		rm $(LOG_DIR)/sleep-monitor-error.log; \
		echo "✓ Removed error log file"; \
	fi
	@echo "✓ Sleep Prevention Monitor has been uninstalled"

status: ## Check the status of the sleep monitor service
	@echo "Sleep Prevention Monitor Status:"
	@echo
	@if launchctl list | grep -q $(SERVICE_NAME); then \
		echo "✓ Service is loaded"; \
		launchctl list $(SERVICE_NAME); \
	else \
		echo "✗ Service is not loaded"; \
	fi
	@echo
	@if [ -f $(PLIST_FILE) ]; then \
		echo "✓ Configuration file exists: $(PLIST_FILE)"; \
	else \
		echo "✗ Configuration file missing"; \
	fi
	@echo
	@if [ -f $(LOG_DIR)/sleep-monitor.log ]; then \
		echo "Recent log entries:"; \
		tail -n 5 $(LOG_DIR)/sleep-monitor.log; \
	else \
		echo "No log file found"; \
	fi