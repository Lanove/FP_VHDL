import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np
from collections import deque
import threading
import queue

# --- Configuration ---
# IMPORTANT: Set these values to match your hardware setup.
SERIAL_PORT = (
    "/dev/ttyUSB0"  # Change this! e.g., 'COM3' on Windows, '/dev/ttyUSB0' on Linux
)
BAUD_RATE = 3000000  # Change this to match the baud rate set in your VHDL

# Plotting settings
MAX_SAMPLES_TO_PLOT = 500  # Number of recent samples to display on the plot
PLOT_UPDATE_INTERVAL_MS = 50  # How often to update the plot (in milliseconds)

# --- State Machine for Parsing (used in reader thread) ---
STATE_WAIT_HEADER_1 = 0
STATE_WAIT_HEADER_2 = 1
STATE_READ_DATA = 2


def setup_serial(port, baud):
    """Attempts to configure and open the serial port."""
    try:
        ser = serial.Serial(port, baud, timeout=1)
        print(f"Successfully opened serial port {port} at {baud} baud.")
        return ser
    except serial.SerialException as e:
        print(
            f"Error: Could not open serial port {port}. Please check the port name and permissions."
        )
        print(f"Details: {e}")
        return None


def serial_reader_thread(ser, data_queue, stop_event):
    """
    This function runs in a separate thread and continuously reads from the serial port.
    It parses data frames and puts the results into a thread-safe queue.
    """
    current_state = STATE_WAIT_HEADER_1
    data_buffer = []

    while not stop_event.is_set():
        try:
            # Read all available bytes to process them in a batch
            if ser.in_waiting > 0:
                bytes_in = ser.read(ser.in_waiting)
                for byte_in in bytes_in:
                    # --- FSM Logic ---
                    if current_state == STATE_WAIT_HEADER_1:
                        if byte_in == 0xAE:
                            current_state = STATE_WAIT_HEADER_2

                    elif current_state == STATE_WAIT_HEADER_2:
                        if byte_in == 0xBC:
                            data_buffer = []  # Clear buffer for new data
                            current_state = STATE_READ_DATA
                        else:
                            current_state = STATE_WAIT_HEADER_1

                    elif current_state == STATE_READ_DATA:
                        data_buffer.append(byte_in)
                        if len(data_buffer) == 4:
                            d0_h, d0_l, d1_h, d1_l = data_buffer
                            adc_val_0 = (d0_h << 4) | (d0_l >> 4)
                            adc_val_1 = (d1_h << 4) | (d1_l >> 4)

                            # Put the complete data packet into the queue
                            data_queue.put((adc_val_0, adc_val_1))

                            current_state = STATE_WAIT_HEADER_1
        except Exception as e:
            print(f"Error in reader thread: {e}")
            break
    print("Reader thread stopped.")


def main():
    ser = setup_serial(SERIAL_PORT, BAUD_RATE)
    if not ser:
        return

    data_queue = queue.Queue()
    ch0_data = deque(maxlen=MAX_SAMPLES_TO_PLOT)
    ch1_data = deque(maxlen=MAX_SAMPLES_TO_PLOT)

    # --- Create One Figure with Two Subplots ---
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
    
    # Channel 0 subplot
    (line1,) = ax1.plot(
        [], [], marker="o", markersize=0, linestyle="-", label="ADC Channel 0"
    )
    ax1.set_title("Live ADC Data - Channel 0", fontsize=14)
    ax1.set_xlabel("Sample Number (most recent)", fontsize=11)
    ax1.set_ylabel("ADC Value (12-bit)", fontsize=11)
    ax1.legend()
    ax1.grid(True)
    ax1.set_ylim(0, 4096)
    ax1.set_xlim(0, MAX_SAMPLES_TO_PLOT)

    # Channel 1 subplot
    (line2,) = ax2.plot(
        [], [], marker="x", markersize=0, linestyle="-", color="r", label='ADC Channel 1 (x"234")'
    )
    ax2.set_title("Live ADC Data - Channel 1", fontsize=14)
    ax2.set_xlabel("Sample Number (most recent)", fontsize=11)
    ax2.set_ylabel("ADC Value (12-bit)", fontsize=11)
    ax2.legend()
    ax2.grid(True)
    ax2.set_ylim(0, 4096)
    ax2.set_xlim(0, MAX_SAMPLES_TO_PLOT)

    # Adjust layout to prevent overlap
    plt.tight_layout()

    # --- Define single update function for both subplots ---
    def update_plots(frame):
        # Pull any new data from the queue
        while not data_queue.empty():
            try:
                adc0, adc1 = data_queue.get_nowait()
                ch0_data.append(adc0)
                ch1_data.append(adc1)
            except queue.Empty:
                break
        
        # Update both lines
        line1.set_data(np.arange(len(ch0_data)), ch0_data)
        line2.set_data(np.arange(len(ch1_data)), ch1_data)
        return (line1, line2)

    # --- Start Reader Thread ---
    stop_event = threading.Event()
    reader_thread = threading.Thread(
        target=serial_reader_thread, args=(ser, data_queue, stop_event)
    )
    reader_thread.daemon = True
    reader_thread.start()

    print("Starting data acquisition... Close the plot window to stop.")

    # --- Create single animation for both subplots ---
    ani = animation.FuncAnimation(
        fig, update_plots, blit=True, interval=PLOT_UPDATE_INTERVAL_MS
    )

    try:
        plt.show()  # This will block until the window is closed
    except Exception as e:
        print(f"An error occurred during plotting: {e}")
    finally:
        print("Stopping reader thread...")
        stop_event.set()
        reader_thread.join(timeout=2)
        ser.close()
        print("Serial port closed.")


if __name__ == "__main__":
    main()