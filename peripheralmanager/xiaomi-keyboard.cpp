#include <android/log.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h> // Add for signal handling
#include <time.h> // Add for time functions
#include <ctype.h> // Add for isspace() function

const char kPackageName[] = "xiaomi-keyboard";

#define BUFFER_SIZE 1024

// Device path
#define NANODEV_PATH "/dev/nanodev0"
// We'll find this dynamically
char* EVENT_PATH = NULL;

// logging
#define TAG "xiaomi-keyboard"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)

// Enhanced logging macros
#define LOG_WITH_TIME(level, fmt, ...) do { \
    time_t now = time(NULL); \
    struct tm* tm_info = localtime(&now); \
    char time_str[20]; \
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", tm_info); \
    __android_log_print(level, TAG, "[%s] " fmt, time_str, ##__VA_ARGS__); \
} while(0)

#define LOGE_TIME(fmt, ...) LOG_WITH_TIME(ANDROID_LOG_ERROR, fmt, ##__VA_ARGS__)
#define LOGW_TIME(fmt, ...) LOG_WITH_TIME(ANDROID_LOG_WARN, fmt, ##__VA_ARGS__)
#define LOGI_TIME(fmt, ...) LOG_WITH_TIME(ANDROID_LOG_INFO, fmt, ##__VA_ARGS__)
#define LOGD_TIME(fmt, ...) LOG_WITH_TIME(ANDROID_LOG_DEBUG, fmt, ##__VA_ARGS__)

// Nanodev file
int fd;

// Current kb enabled/disabled state
bool kb_status = true;

// Add signal handler for graceful termination - MOVED HERE
volatile sig_atomic_t terminate = 0;

// Condition variable for pausing and resuming the thread
pthread_mutex_t kb_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t kb_cond = PTHREAD_COND_INITIALIZER;
bool kb_thread_paused = false;

// Add these global variables
time_t last_monitor_activity = 0;
pthread_t watchdog_thread;
bool watchdog_enabled = true;

// Add this near the top of the file, after the global variables
#define CONFIG_PATH "/data/local/tmp/xiaomi_keyboard.conf"

// Configuration loading function
void load_configuration() {
    FILE* config_file = fopen(CONFIG_PATH, "r");
    if (!config_file) {
        LOGI("No configuration file found, using defaults");
        return;
    }
    
    char line[256];
    char key[128], value[128];
    
    while (fgets(line, sizeof(line), config_file) != NULL) {
        // Skip comments and empty lines
        if (line[0] == '#' || line[0] == '\n') continue;
        
        if (sscanf(line, "%127[^=]=%127s", key, value) == 2) {
            // Remove whitespace
            char* p = key + strlen(key) - 1;
            while (p >= key && isspace(*p)) *p-- = '\0';
            
            // Process configuration keys
            if (strcmp(key, "watchdog_enabled") == 0) {
                watchdog_enabled = (strcmp(value, "true") == 0);
                LOGI("Config: watchdog_enabled = %d", watchdog_enabled);
            }
            // Add more configuration options as needed
        }
    }
    
    fclose(config_file);
    LOGI("Configuration loaded from %s", CONFIG_PATH);
}

/**
 * Find the keyboard event input device path
 * This replaces the hardcoded path with dynamic detection
 */
char* find_keyboard_input_path() {
    static char path_buffer[128] = "/dev/input/event12";
    const char* input_dir = "/dev/input";
    DIR* dir = opendir(input_dir);
    
    if (!dir) {
        LOGE("Failed to open input directory");
        return path_buffer;
    }
    
    FILE* device_file;
    char name_path[128];
    char device_name[256];
    struct dirent* entry;
    
    // Enhanced detection with more keywords
    while ((entry = readdir(dir)) != NULL) {
        if (strncmp(entry->d_name, "event", 5) == 0) {
            snprintf(name_path, sizeof(name_path), 
                     "/sys/class/input/%s/device/name", entry->d_name);
            
            device_file = fopen(name_path, "r");
            if (device_file) {
                if (fgets(device_name, sizeof(device_name), device_file)) {
                    // More comprehensive detection criteria
                    if (strstr(device_name, "xiaomi") || 
                        strstr(device_name, "Xiaomi") ||
                        strstr(device_name, "keyboard") ||
                        strstr(device_name, "Keyboard") ||
                        strstr(device_name, "pipa") ||
                        strstr(device_name, "Pipa") ||
                        strstr(device_name, "XKBD")) {
                        
                        snprintf(path_buffer, sizeof(path_buffer), 
                                 "/dev/input/%s", entry->d_name);
                        LOGI("Found keyboard at: %s - Device: %s", 
                             path_buffer, device_name);
                        fclose(device_file);
                        closedir(dir);
                        return path_buffer;
                    }
                }
                fclose(device_file);
            }
        }
    }
    
    closedir(dir);
    LOGW("Could not find keyboard device, using default path");
    return path_buffer;
}

/**
 * Set keyboard state directly
 */
void set_kb_state(bool value, bool force) {
    if (kb_status != value || force) {
        kb_status = value;
        LOGI("Setting keyboard state to: %d", value);
        unsigned char buf[3] = {0x32, 0xFF, (unsigned char)value};
        if (write(fd, &buf, 3) != 3) {
            LOGE("Failed to write keyboard state");
        }
    }
}

// Improved keyboard status monitoring with debouncing
#define DEBOUNCE_COUNT 3

void *keyboard_monitor_thread(void *arg) {
    (void)arg;
    
    int connection_state_count = 0;
    bool last_state = access(EVENT_PATH, F_OK) != -1;
    
    while (!terminate) {
        bool current_state = (access(EVENT_PATH, F_OK) != -1);
        
        // Debounce connection state changes
        if (current_state != last_state) {
            connection_state_count++;
            LOGD("Potential keyboard connection change detected (%d/%d)", 
                 connection_state_count, DEBOUNCE_COUNT);
        } else {
            connection_state_count = 0;
        }
        
        // Only process state change after debounce count
        if (connection_state_count >= DEBOUNCE_COUNT) {
            last_state = current_state;
            connection_state_count = 0;
            
            pthread_mutex_lock(&kb_mutex);
            last_monitor_activity = time(NULL);
            
            if (!kb_thread_paused) {
                if (current_state && !kb_status) {
                    LOGI("Keyboard connected - enabling");
                    set_kb_state(true, false);
                } else if (!current_state && kb_status) {
                    LOGI("Keyboard disconnected - disabling");
                    set_kb_state(false, false);
                }
            }
            pthread_mutex_unlock(&kb_mutex);
        }
        
        // More efficient sleep pattern
        for (int i = 0; i < 5 && !terminate; i++) {
            usleep(200000); // 5 * 200ms = 1 second total, but more responsive
        }
    }
    
    LOGI("Keyboard monitor thread exiting");
    return NULL;
}

// Add this watchdog thread function
void *watchdog_thread_func(void *arg) {
    (void)arg; // Suppress unused parameter warning
    
    const int WATCHDOG_INTERVAL = 30; // 30 seconds
    
    LOGI("Watchdog thread started");
    
    while (!terminate) {
        sleep(10); // Check every 10 seconds
        
        time_t now = time(NULL);
        pthread_mutex_lock(&kb_mutex);
        time_t last_activity = last_monitor_activity;
        pthread_mutex_unlock(&kb_mutex);
        
        // If monitor thread hasn't updated in WATCHDOG_INTERVAL, it might be stuck
        if (now - last_activity > WATCHDOG_INTERVAL && watchdog_enabled) {
            LOGW("Watchdog: Monitor thread appears stuck for %d seconds", 
                 (int)(now - last_activity));
            
            // Signal the condition to try to wake up the thread
            pthread_mutex_lock(&kb_mutex);
            pthread_cond_signal(&kb_cond);
            pthread_mutex_unlock(&kb_mutex);
        }
    }
    
    LOGI("Watchdog thread exiting");
    return NULL;
}

// Define message types for better readability
#define MSG_TYPE_SLEEP 37
#define MSG_TYPE_WAKE 40
#define MSG_HEADER_1 0x31
#define MSG_HEADER_2 0x38

/**
 * Event handler for wake/sleep messages
 */
void handle_power_event(char *buffer) {
    bool is_wake = (buffer[6] == 1);
    
    if (is_wake) {
        // Wake event
        LOGI("Received wake event - enabling keyboard monitoring");
        pthread_mutex_lock(&kb_mutex);
        kb_thread_paused = false;
        last_monitor_activity = time(NULL); // Reset watchdog timer
        pthread_cond_signal(&kb_cond);
        pthread_mutex_unlock(&kb_mutex);

        // Re-check keyboard connection status immediately
        bool keyboard_connected = (access(EVENT_PATH, F_OK) != -1);
        LOGI("Wake: Keyboard %s", keyboard_connected ? "connected" : "disconnected");
        
        // Restore keyboard state based on current connection
        if (keyboard_connected) {
            set_kb_state(true, true);
        } else {
            kb_status = false;
        }
    } else {
        // Sleep event
        LOGI("Received sleep event - pausing keyboard monitoring");
        pthread_mutex_lock(&kb_mutex);
        kb_thread_paused = true;
        pthread_mutex_unlock(&kb_mutex);
    }
}

/**
 * Main event handler - dispatches to appropriate handler based on message type
 */
void handle_event(char *buffer, ssize_t bytes_read) {
    // More comprehensive validation
    if (bytes_read < 7) {
        LOGD("Message too short: %zd bytes", bytes_read);
        return;
    }
    
    // Log message details at debug level
    LOGD("Received message: type=%d, headers=[%02x,%02x]", 
         buffer[4], buffer[1], buffer[2]);
    
    // Improved header validation
    if (!(buffer[0] == 34 || buffer[0] == 35 || buffer[0] == 36 || buffer[0] == 38)) {
        LOGD("Invalid message prefix: %02x", buffer[0]);
        return;
    }
    
    if (buffer[1] != MSG_HEADER_1 || buffer[2] != MSG_HEADER_2) {
        LOGD("Invalid message headers: %02x,%02x", buffer[1], buffer[2]);
        return;
    }
    
    // Handle message based on type
    switch (buffer[4]) {
        case MSG_TYPE_SLEEP:
            LOGD("Processing sleep message");
            if (buffer[5] == 1) {
                handle_power_event(buffer);
            }
            break;
            
        case MSG_TYPE_WAKE:
            LOGD("Processing wake message");
            if (buffer[5] == 1) {
                handle_power_event(buffer);
            }
            break;
            
        default:
            // Unknown message type with hex logging
            LOGD("Unhandled message type: %d (0x%02x)", buffer[4], buffer[4]);
            break;
    }
}

/**
 * Attempt to reconnect to the device with exponential backoff
 * Returns: file descriptor on success, -1 on failure
 */
int reconnect_device() {
    int attempts = 0;
    const int max_attempts = 10; // Increased from 5
    int new_fd = -1;
    
    LOGI("Starting device reconnection procedure");
    
    while (attempts < max_attempts && new_fd == -1 && !terminate) {
        LOGI("Reconnect attempt %d/%d", attempts + 1, max_attempts);
            
        new_fd = open(NANODEV_PATH, O_RDWR);
        if (new_fd != -1) {
            LOGI("Successfully reconnected to device");
            return new_fd;
        }
        
        // Log specific error
        LOGE("Reconnection attempt failed: %s", strerror(errno));
        
        // Exponential backoff with cap
        int sleep_time = (1 << attempts) * 500000; // 0.5s, 1s, 2s, 4s, 8s...
        if (sleep_time > 8000000) sleep_time = 8000000; // Max 8 seconds
        
        LOGI("Waiting %0.1f seconds before next attempt", sleep_time/1000000.0);
        usleep(sleep_time);
        attempts++;
    }
    
    if (terminate) {
        LOGI("Reconnection aborted due to termination request");
    } else {
        LOGE("Failed to reconnect after %d attempts", max_attempts);
    }
    return -1;
}

// Add signal handler for graceful termination
void signal_handler(int signum) {
    LOGI("Caught signal %d, terminating...", signum);
    terminate = 1;
}

/**
 * Main function
 */
int main() {
    // Add program start timestamp
    time_t start_time = time(NULL);
    struct tm* tm_info = localtime(&start_time);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", tm_info);
    
    LOGI("==================================================");
    LOGI("Xiaomi keyboard service starting at %s", time_str);
    LOGI("==================================================");
    
    // Load configuration
    load_configuration();
    
    ssize_t bytes_read;
    char buffer[BUFFER_SIZE];

    // Initialize log
    LOGI_TIME("Xiaomi keyboard service starting...");

    // Dynamic path detection 
    EVENT_PATH = find_keyboard_input_path();
    LOGI("Using keyboard input path: %s", EVENT_PATH);

    // Open the nanodev device file
    fd = open(NANODEV_PATH, O_RDWR);
    if (fd == -1) {
        LOGE("Error opening nanodev device: %s", strerror(errno));
        return errno;
    }

    // Check current keyboard status
    if (access(EVENT_PATH, F_OK) == -1) {
        kb_status = false;
        LOGW("Keyboard input device not found, starting disabled");
    } else {
        LOGI("Keyboard input device found, starting enabled");
        set_kb_state(true, true);
    }

    // Create the keyboard monitor thread
    pthread_t monitor_thread;
    if (pthread_create(&monitor_thread, NULL, keyboard_monitor_thread, NULL) != 0) {
        LOGE("Failed to create keyboard monitor thread");
        close(fd);
        return EXIT_FAILURE;
    }

    // Create watchdog thread after creating monitor thread
    if (pthread_create(&watchdog_thread, NULL, watchdog_thread_func, NULL) != 0) {
        LOGW("Failed to create watchdog thread - continuing without watchdog");
    }

    // Set up signal handling
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // Main loop for keyboard events
    LOGI("Main loop starting, ready to receive keyboard events");
    while (!terminate) {
        // Read data from the device
        bytes_read = read(fd, buffer, BUFFER_SIZE);
        
        if (bytes_read > 0) {
            // Process the message
            handle_event(buffer, bytes_read);
        } 
        else if (bytes_read == 0) {
            // No data available, sleep before trying again
            usleep(100000); // 100ms
        } 
        else {
            // Read error occurred
            LOGE("Error reading device: %s", strerror(errno));
            
            // Close the current file descriptor
            close(fd);
            
            // Try to reconnect with backoff
            fd = reconnect_device();
            
            // If reconnection failed, exit the loop
            if (fd == -1) {
                LOGE("Could not recover device connection, exiting");
                break;
            }
        }
    }

    // Final status report before exit
    time_t end_time = time(NULL);
    double runtime = difftime(end_time, start_time);
    LOGI("==================================================");
    LOGI("Service exiting after running for %.1f seconds", runtime);
    LOGI("==================================================");

    // Cleanup
    LOGI("Performing cleanup...");
    // Replace pthread_cancel with a more compatible approach
    pthread_mutex_lock(&kb_mutex);
    terminate = 1;  // Signal the thread to exit
    pthread_cond_signal(&kb_cond); // Wake up the thread if it's waiting
    pthread_mutex_unlock(&kb_mutex);

    // Join the thread to wait for it to finish
    pthread_join(monitor_thread, NULL);
    pthread_join(watchdog_thread, NULL);
    close(fd);

    return 0;
}