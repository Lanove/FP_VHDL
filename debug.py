import serial
import time

class SerialDebugger:
    def __init__(self, port, baud_rate=3000000):
        self.port = port
        self.baud_rate = baud_rate
        self.ser = None
        
    def connect_serial(self):
        try:
            self.ser = serial.Serial(self.port, self.baud_rate, timeout=1)
            print(f"Connected to {self.port} at {self.baud_rate} baud")
            print("Waiting for data...\n")
            return True
        except serial.SerialException as e:
            print(f"Failed to connect to {self.port}: {e}")
            return False
    
    def debug_raw_bytes(self):
        """Print every byte received with hex and decimal values"""
        if not self.connect_serial():
            return
            
        byte_count = 0
        packet_count = 0
        line_bytes = []
        
        print("Raw Serial Data Debug:")
        print("Format: [ByteCount] HEX (DEC) 'ASCII'")
        print("-" * 50)
        
        try:
            while True:
                byte_data = self.ser.read(1)
                if len(byte_data) > 0:
                    byte_val = byte_data[0]
                    
                    # Convert to ASCII if printable, otherwise show as '.'
                    ascii_char = chr(byte_val) if 32 <= byte_val <= 126 else '.'
                    
                    # Print byte info
                    print(f"[{byte_count:06d}] 0x{byte_val:02X} ({byte_val:3d}) '{ascii_char}'")
                    
                    # Add to line buffer for pattern detection
                    line_bytes.append(byte_val)
                    byte_count += 1
                    
                    # Check for sync pattern (0xFF 0xFF)
                    if len(line_bytes) >= 2 and line_bytes[-2:] == [0xFF, 0xFF]:
                        print(f"*** SYNC HEADER DETECTED at byte {byte_count-1} ***")
                        packet_count += 1
                        
                    # Keep only last 10 bytes for pattern detection
                    if len(line_bytes) > 10:
                        line_bytes.pop(0)
                        
                    # Print packet boundary every 6 bytes after sync
                    if byte_count % 6 == 0:
                        print("-" * 30)
                        
        except KeyboardInterrupt:
            print(f"\nStopped. Received {byte_count} bytes, detected {packet_count} sync headers")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()
                print("Serial connection closed")
    
    def debug_packet_structure(self):
        """Debug with packet structure interpretation"""
        if not self.connect_serial():
            return
            
        print("Packet Structure Debug:")
        print("Looking for: [0xFF][0xFF][ADC_H][ADC_L][FILT_H][FILT_L]")
        print("-" * 60)
        
        packet_buffer = []
        packet_count = 0
        byte_count = 0
        
        try:
            while True:
                byte_data = self.ser.read(1)
                if len(byte_data) > 0:
                    byte_val = byte_data[0]
                    byte_count += 1
                    
                    print(f"[{byte_count:06d}] 0x{byte_val:02X} ({byte_val:3d})", end="")
                    
                    # Look for sync pattern
                    if byte_val == 0xFF:
                        if len(packet_buffer) == 0:
                            packet_buffer.append(byte_val)
                            print(" <- First sync byte")
                        elif len(packet_buffer) == 1 and packet_buffer[0] == 0xFF:
                            packet_buffer.append(byte_val)
                            print(" <- Second sync byte - PACKET START")
                            packet_count += 1
                        else:
                            packet_buffer = [byte_val]
                            print(" <- Possible sync start")
                    else:
                        if len(packet_buffer) >= 2:
                            packet_buffer.append(byte_val)
                            
                            if len(packet_buffer) == 3:
                                print(" <- ADC High Byte")
                            elif len(packet_buffer) == 4:
                                adc_val = (packet_buffer[2] << 8) | packet_buffer[3]
                                print(f" <- ADC Low Byte (ADC = {adc_val})")
                            elif len(packet_buffer) == 5:
                                print(" <- Filter High Byte")
                            elif len(packet_buffer) == 6:
                                filt_val = (packet_buffer[4] << 8) | packet_buffer[5]
                                # Convert to signed
                                if filt_val > 32767:
                                    filt_val -= 65536
                                print(f" <- Filter Low Byte (FILT = {filt_val})")
                                
                                # Complete packet received
                                adc_final = (packet_buffer[2] << 8) | packet_buffer[3]
                                adc_final &= 0x0FFF  # 12-bit mask
                                print(f"*** PACKET {packet_count} COMPLETE: ADC={adc_final}, FILT={filt_val} ***")
                                print()
                                packet_buffer = []
                        else:
                            packet_buffer = []
                            print(" <- Data byte (no sync)")
                            
        except KeyboardInterrupt:
            print(f"\nStopped. Processed {byte_count} bytes, {packet_count} complete packets")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()
                print("Serial connection closed")
    
    def debug_hex_dump(self, bytes_per_line=16):
        """Print hex dump style output"""
        if not self.connect_serial():
            return
            
        print("Hex Dump Debug:")
        print("-" * 60)
        
        byte_count = 0
        line_buffer = []
        
        try:
            while True:
                byte_data = self.ser.read(1)
                if len(byte_data) > 0:
                    byte_val = byte_data[0]
                    line_buffer.append(byte_val)
                    byte_count += 1
                    
                    # Print line when buffer is full
                    if len(line_buffer) >= bytes_per_line:
                        self.print_hex_line(byte_count - bytes_per_line, line_buffer)
                        line_buffer = []
                        
        except KeyboardInterrupt:
            # Print remaining bytes
            if line_buffer:
                self.print_hex_line(byte_count - len(line_buffer), line_buffer)
            print(f"\nStopped. Received {byte_count} bytes total")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()
                print("Serial connection closed")
    
    def print_hex_line(self, start_addr, byte_list):
        """Print a line in hex dump format"""
        # Address
        addr_str = f"{start_addr:08X}:"
        
        # Hex bytes
        hex_str = " ".join(f"{b:02X}" for b in byte_list)
        hex_str = hex_str.ljust(48)  # Pad to fixed width
        
        # ASCII representation
        ascii_str = "".join(chr(b) if 32 <= b <= 126 else '.' for b in byte_list)
        
        print(f"{addr_str} {hex_str} |{ascii_str}|")

def main():
    # Configuration
    SERIAL_PORT = '/dev/ttyUSB0'  # Adjust for your system
    # BAUD_RATE = 3000000
    
    debugger = SerialDebugger(SERIAL_PORT)
    
    print("Serial Debug Tool")
    print("1. Raw byte debug (every byte with details)")
    print("2. Packet structure debug (interpret as packets)")
    print("3. Hex dump debug (hex dump format)")
    
    choice = input("Enter choice (1, 2, or 3): ").strip()
    
    if choice == '1':
        debugger.debug_raw_bytes()
    elif choice == '2':
        debugger.debug_packet_structure()
    elif choice == '3':
        debugger.debug_hex_dump()
    else:
        print("Invalid choice")

if __name__ == "__main__":
    main()