import serial
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from collections import deque
import struct
import time

class UARTRealTimePlotter:
    def __init__(self, port, baud_rate=921600, sample_rate=25000, window_time=0.1):
        self.port = port
        self.baud_rate = baud_rate
        self.sample_rate = sample_rate  # Updated to 25kHz to match FPGA
        self.window_time = window_time  # Window time in seconds
        
        # Calculate buffer size based on sample rate and window time
        self.buffer_size = int(self.sample_rate * self.window_time)
        
        # Data buffers - only store what we need for the window
        self.adc_buffer = deque(maxlen=self.buffer_size)
        self.filtered_buffer = deque(maxlen=self.buffer_size)
        
        # Serial connection
        self.ser = None
        self.sample_count = 0
        
        # Initialize plot
        self.fig, (self.ax1, self.ax2) = plt.subplots(2, 1, figsize=(12, 8))
        self.line1, = self.ax1.plot([], [], 'b-', label='Raw ADC (normalized)', linewidth=1)
        self.line2, = self.ax2.plot([], [], 'r-', label='Filtered (normalized)', linewidth=1)
        
        self.setup_plots()
        
    def setup_plots(self):
        # Setup ADC plot (normalized to -1 to +1)
        self.ax1.set_title(f'Real-time ADC Data - Last {self.window_time}s @ {self.sample_rate}Hz')
        self.ax1.set_ylabel('Normalized ADC Value')
        self.ax1.set_xlabel('Sample Index')
        self.ax1.set_ylim(0, 4095)
        self.ax1.set_xlim(0, self.buffer_size)
        self.ax1.grid(True, alpha=0.3)
        self.ax1.legend()
        
        # Setup filtered data plot (normalized to -1 to +1)
        self.ax2.set_title(f'Real-time Filtered Data - Last {self.window_time}s @ {self.sample_rate}Hz')
        self.ax2.set_xlabel('Sample Index')
        self.ax2.set_ylabel('Normalized Filtered Value')
        self.ax2.set_ylim(0, 4095)
        self.ax2.set_xlim(0, self.buffer_size)
        self.ax2.grid(True, alpha=0.3)
        self.ax2.legend()
        
        plt.tight_layout()
        
    def normalize_adc(self, adc_value):
        """Normalize ADC value from 0-4095 to -1 to +1"""
        return adc_value
        
    def normalize_filtered(self, filtered_value):
        """Normalize filtered value from 0-4095 to -1 to +1 (same as ADC)"""
        return filtered_value
        
    def connect_serial(self):
        try:
            self.ser = serial.Serial(self.port, self.baud_rate, timeout=1)
            print(f"Connected to {self.port} at {self.baud_rate} baud")
            print(f"Sample rate: {self.sample_rate}Hz, Window: {self.window_time}s ({self.buffer_size} samples)")
            return True
        except serial.SerialException as e:
            print(f"Failed to connect to {self.port}: {e}")
            return False
            
    def find_sync_header(self):
        """Find the 0xAE 0xAE sync header"""
        sync_bytes = b''
        while len(sync_bytes) < 2:
            byte = self.ser.read(1)
            if len(byte) == 0:
                continue
                
            if byte == b'\xae':
                sync_bytes += byte
                if len(sync_bytes) == 2:
                    return True
            else:
                sync_bytes = b''
        return False
        
    def read_packet(self):
        """Read a complete 6-byte packet: [0xFF][0xFF][ADC_H][ADC_L][FILT_H][FILT_L]"""
        try:
            # Find sync header
            if not self.find_sync_header():
                return None, None
                
            # Read data bytes
            data_bytes = self.ser.read(4)
            if len(data_bytes) != 4:
                return None, None
                
            # Parse ADC data (16-bit, but only 12 bits used)
            adc_value = (data_bytes[0] << 8) | data_bytes[1]
            adc_value &= 0x0FFF  # Mask to 12 bits (0-4095)
            
            # Parse filtered data (16-bit signed)
            # filtered_value = struct.unpack('>h', data_bytes[2:4])[0]  # Big-endian signed short
            
            filtered_value = (data_bytes[2] << 8) | data_bytes[3]
            filtered_value &= 0x0FFF  # Mask to 12 bits (0-4095)
            
            return adc_value, filtered_value
            
        except Exception as e:
            print(f"Error reading packet: {e}")
            return None, None
            
    def update_plot(self, frame):
        """Animation update function"""
        if self.ser is None or not self.ser.is_open:
            return self.line1, self.line2
            
        # Read multiple packets per frame for better performance
        packets_per_frame = min(50, self.buffer_size // 10)  # Adaptive based on buffer size
        
        for _ in range(packets_per_frame):
            # Use the main packet reading method
            adc_val, filt_val = self.read_packet()
            if adc_val is not None and filt_val is not None:
                # Normalize the data to -1 to +1 range
                normalized_adc = self.normalize_adc(adc_val)
                normalized_filtered = self.normalize_filtered(filt_val)
                
                # Add to buffers (deque automatically handles overflow)
                self.adc_buffer.append(normalized_adc)
                self.filtered_buffer.append(normalized_filtered)
                
                self.sample_count += 1
                
        # Update plots if we have data
        if len(self.adc_buffer) > 0:
            # Create sample indices for x-axis
            x_data = np.arange(len(self.adc_buffer))
            adc_array = np.array(list(self.adc_buffer))
            filtered_array = np.array(list(self.filtered_buffer))
            
            # Update line data
            self.line1.set_data(x_data, adc_array)
            self.line2.set_data(x_data, filtered_array)
            
            # Update x-axis limits to show current buffer content
            if len(x_data) > 0:
                self.ax1.set_xlim(0, max(len(x_data), self.buffer_size))
                self.ax2.set_xlim(0, max(len(x_data), self.buffer_size))
        
        return self.line1, self.line2
        
    def start_plotting(self):
        """Start the real-time plotting"""
        if not self.connect_serial():
            return
            
        print("Starting real-time plot... Press Ctrl+C to stop")
        print(f"Displaying last {self.window_time}s of data ({self.buffer_size} samples)")
        print("Waiting for data...")
        print("Packet format: [0xAE][0xAE][RAW_H][RAW_L][FILT_H][FILT_L] (6 bytes total)")
        
        # Create animation with adaptive interval
        update_interval = max(20, int(1000 / (self.sample_rate / 100)))  # Adaptive update rate
        ani = animation.FuncAnimation(
            self.fig, self.update_plot, interval=update_interval,
            blit=True, cache_frame_data=False
        )
        
        try:
            plt.show()
        except KeyboardInterrupt:
            print("\nStopping...")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()
                print("Serial connection closed")
                
    def save_data(self, filename, duration_seconds=10):
        """Save data to file for later analysis"""
        if not self.connect_serial():
            return
            
        print(f"Collecting data for {duration_seconds} seconds...")
        
        raw_adc_data = []
        raw_filtered_data = []
        normalized_adc_data = []
        normalized_filtered_data = []
        
        start_time = time.time()
        sample_count = 0
        
        try:
            while time.time() - start_time < duration_seconds:
                adc_val, filt_val = self.read_packet()
                if adc_val is not None and filt_val is not None:
                    # Store both raw and normalized data
                    raw_adc_data.append(adc_val)
                    raw_filtered_data.append(filt_val)
                    normalized_adc_data.append(self.normalize_adc(adc_val))
                    normalized_filtered_data.append(self.normalize_filtered(filt_val))
                    sample_count += 1
                    
                    if sample_count % 1000 == 0:
                        print(f"Collected {sample_count} samples...")
                        
        except KeyboardInterrupt:
            print("Data collection interrupted")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()
                
        # Save to numpy file
        np.savez(filename, 
                raw_adc_data=np.array(raw_adc_data),
                raw_filtered_data=np.array(raw_filtered_data),
                normalized_adc_data=np.array(normalized_adc_data),
                normalized_filtered_data=np.array(normalized_filtered_data),
                sample_rate=self.sample_rate)
        
        print(f"Data saved to {filename}")
        print(f"Collected {len(raw_adc_data)} samples")
        print("Saved both raw and normalized data")

    def debug_packets(self, num_packets=10):
        """Debug function to see raw packet data"""
        if not self.connect_serial():
            return
            
        print(f"Reading {num_packets} packets for debugging...")
        print("Format: [Header1][Header2][RAW_H][RAW_L][FILT_H][FILT_L] -> Raw_ADC, Filtered")
        
        try:
            for i in range(num_packets):
                if self.find_sync_header():
                    data_bytes = self.ser.read(4)
                    if len(data_bytes) == 4:
                        # Parse the packet manually for debugging
                        adc_value = (data_bytes[0] << 8) | data_bytes[1]
                        adc_value = adc_value & 0x0FFF
                        
                        filtered_value = (data_bytes[2] << 8) | data_bytes[3]
                        filtered_value = filtered_value & 0x0FFF
                        
                        print(f"Packet {i+1}: [0xAE][0xAE][0x{data_bytes[0]:02X}][0x{data_bytes[1]:02X}][0x{data_bytes[2]:02X}][0x{data_bytes[3]:02X}] -> ADC:{adc_value} ({adc_value:04X}), Filtered:{filtered_value} ({filtered_value:04X})")
                    else:
                        print(f"Packet {i+1}: Incomplete data - got {len(data_bytes)} bytes")
                else:
                    print(f"Packet {i+1}: No sync header found")
        except Exception as e:
            print(f"Debug error: {e}")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()

    def hex_dump_packets(self, num_packets=10):
        """Hexdump function to see raw stream"""
        if not self.connect_serial():
            return
            
        print(f"Reading raw data stream for hex dump...")
        print("Looking for 0xAE 0xAE sync patterns...")
        
        try:
            raw_data = self.ser.read(num_packets * 10)  # Read more data than expected
            
            # Convert to hex dump format
            for i in range(0, len(raw_data), 16):
                chunk = raw_data[i:i+16]
                hex_str = ' '.join([f'{b:02X}' for b in chunk])
                ascii_str = ''.join([chr(b) if 32 <= b <= 126 else '.' for b in chunk])
                print(f"{i:08X}: {hex_str:<48} |{ascii_str}|")
                
            # Look for sync patterns
            print("\nSync pattern analysis:")
            for i in range(len(raw_data) - 1):
                if raw_data[i] == 0xAE and raw_data[i+1] == 0xAE:
                    print(f"Found sync at offset {i:04X}")
                    
        except Exception as e:
            print(f"Hex dump error: {e}")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()

def main():
    # Configuration
    SERIAL_PORT = '/dev/ttyUSB0'  # Adjust for your system (Windows: 'COM3', etc.)
    BAUD_RATE = 921600  # Match FPGA baud rate
    
    print("UART Real-time Plotter Configuration")
    print("Default settings:")
    print(f"  Port: {SERIAL_PORT}")
    print(f"  Baud rate: {BAUD_RATE}")
    print(f"  Sample rate: 25000 Hz")
    print(f"  Window time: 0.1 seconds")
    print()
    
    # Get user configuration
    use_defaults = input("Use default settings? (y/n): ").strip().lower()
    
    if use_defaults != 'y':
        port = input(f"Enter serial port ({SERIAL_PORT}): ").strip() or SERIAL_PORT
        baud = input(f"Enter baud rate ({BAUD_RATE}): ").strip()
        baud_rate = int(baud) if baud else BAUD_RATE
        
        sample_str = input("Enter sample rate (25000): ").strip()
        sample_rate = int(sample_str) if sample_str else 25000
        
        window_str = input("Enter window time in seconds (0.1): ").strip()
        window_time = float(window_str) if window_str else 0.1
    else:
        port = SERIAL_PORT
        baud_rate = BAUD_RATE
        sample_rate = 25000
        window_time = 0.01  # Shorter window for testing
    
    plotter = UARTRealTimePlotter(port, baud_rate, sample_rate, window_time)
    
    print("\nUART Real-time Plotter")
    print("1. Real-time plot")
    print("2. Save data to file")
    print("3. Debug packets")
    print("4. Hex dump raw data")
    
    choice = input("Enter choice (1, 2, 3, or 4): ").strip()
    
    if choice == '1':
        plotter.start_plotting()
    elif choice == '2':
        duration = float(input("Enter duration in seconds: "))
        filename = input("Enter filename (without extension): ")
        plotter.save_data(f"{filename}.npz", duration)
    elif choice == '3':
        num_packets = int(input("Enter number of packets to debug (10): ") or "10")
        plotter.debug_packets(num_packets)
    elif choice == '4':
        num_packets = int(input("Enter number of packets worth of data to dump (10): ") or "10")
        plotter.hex_dump_packets(num_packets)
    else:
        print("Invalid choice")

if __name__ == "__main__":
    main()