import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
import math

def design_fir_filter():
    # Filter specifications
    fs = 50000  # Sampling frequency in Hz
    fc = 1100   # Cutoff frequency in Hz
    
    # Normalized cutoff frequency (0 to 1, where 1 is Nyquist frequency)
    nyquist = fs / 2
    normalized_cutoff = fc / nyquist * 0.55
    
    # Filter order (higher order = sharper cutoff, more taps)
    filter_order = 31  # Odd number for symmetric filter
    
    # Design FIR filter using window method (Hamming window)
    fir_coefficients = signal.firwin(filter_order, normalized_cutoff, window='cosine', pass_zero='highpass')
    
    # Calculate frequency response
    
    # Print filter information
    print(f"FIR Filter Design:")
    print(f"Sampling Rate: {fs} Hz")
    print(f"Cutoff Frequency: {fc} Hz")
    print(f"Filter Order: {filter_order}")
    print(f"Number of Taps: {len(fir_coefficients)}")
    print(f"Normalized Cutoff: {normalized_cutoff:.4f}")
    
    # Print coefficients (for Verilog implementation)
    print(f"\nFIR Coefficients (first 10):")
    for i in range(min(10, len(fir_coefficients))):
        print(f"h[{i}] = {fir_coefficients[i]:.8f}")
    
    # Convert to 32-bit fixed-point for FPGA implementation
    # Scale coefficients to 32-bit signed integers
    scale_factor = 2**31 - 1  # Maximum value for 32-bit signed integer
    fixed_point_coeffs = np.round(fir_coefficients * scale_factor).astype(np.int64)
    
    # Ensure values fit in 32-bit signed range
    fixed_point_coeffs = np.clip(fixed_point_coeffs, -2**31, 2**31-1).astype(np.int32)
    
    print(f"\nFixed-Point Coefficients (32-bit, first 10):")
    for i in range(min(10, len(fixed_point_coeffs))):
        # Convert to unsigned 32-bit representation for hex display
        coeff_val = int(fixed_point_coeffs[i])  # Convert numpy int32 to Python int
        if coeff_val < 0:
            hex_val = (coeff_val + 2**32) % (2**32)  # Two's complement conversion
        else:
            hex_val = coeff_val
        print(f"coeff[{i:3d}] = 32'h{hex_val:08X};  // {fir_coefficients[i]:12.8f}")
    
    # Calculate frequency response using original floating-point coefficients for accuracy
    w, h = signal.freqz(fir_coefficients, worN=8000)
    frequencies = w * fs / (2 * np.pi)
    
    # Also calculate response for fixed-point version for comparison
    # Normalize fixed-point coefficients back to floating point for freqz
    normalized_fixed_coeffs = fixed_point_coeffs.astype(np.float64) / scale_factor
    w_fixed, h_fixed = signal.freqz(normalized_fixed_coeffs, worN=8000)
    
    # Plot frequency response
    plt.figure(figsize=(15, 10))
    
    # Magnitude response comparison
    plt.subplot(1, 2, 1)
    plt.plot(frequencies, 20 * np.log10(abs(h)), 'b-', label='Floating Point', linewidth=2)
    plt.plot(frequencies, 20 * np.log10(abs(h_fixed)), 'r--', label='32-bit Fixed Point', linewidth=1)
    plt.axvline(fc, color='g', linestyle='--', label=f'Cutoff: {fc} Hz')
    plt.axhline(-3, color='orange', linestyle='--', label='-3 dB')
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Magnitude (dB)')
    plt.title('FIR Filter Frequency Response - Magnitude Comparison')
    plt.grid(True)
    plt.legend()
    plt.xlim(0, 10000)
    # plt.ylim(-100, 10)
    
    # Phase response
    plt.subplot(1, 2, 2)
    plt.plot(frequencies, np.angle(h) * 180 / np.pi, 'b-', label='Floating Point', linewidth=2)
    plt.plot(frequencies, np.angle(h_fixed) * 180 / np.pi, 'r--', label='32-bit Fixed Point', linewidth=1)
    plt.axvline(fc, color='g', linestyle='--', label=f'Cutoff: {fc} Hz')
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Phase (degrees)')
    plt.title('FIR Filter Frequency Response - Phase Comparison')
    plt.grid(True)
    plt.legend()
    plt.xlim(0, 10000)
    
    # Quantization error
    # plt.subplot(2, 2, 3)
    quantization_error = fir_coefficients - normalized_fixed_coeffs
    # plt.plot(quantization_error, 'r-', linewidth=1)
    # plt.title('Quantization Error (Float - Fixed)')
    # plt.xlabel('Coefficient Index')
    # plt.ylabel('Error')
    # plt.grid(True)
    
    # # Coefficient distribution
    # plt.subplot(2, 2, 4)
    # plt.hist(fir_coefficients, bins=50, alpha=0.7, label='Float Coeffs', density=True)
    # plt.hist(normalized_fixed_coeffs, bins=50, alpha=0.7, label='Fixed Coeffs', density=True)
    # plt.title('Coefficient Distribution')
    # plt.xlabel('Coefficient Value')
    # plt.ylabel('Density')
    # plt.legend()
    # plt.grid(True)
    
    plt.tight_layout()
    plt.savefig('fir_filter_response_32bit.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    # ...existing code...

# Save coefficients to file for Verilog use
    with open('fir_coefficients_32bit.txt', 'w') as f:
        f.write(f"// FIR Filter Coefficients (32-bit)\n")
        f.write(f"// Sampling Rate: {fs} Hz\n")
        f.write(f"// Cutoff Frequency: {fc} Hz\n")
        f.write(f"// Filter Order: {filter_order}\n")
        f.write(f"// Number of Taps: {len(fir_coefficients)}\n")
        f.write(f"// Scale Factor: 2^31 - 1 = {scale_factor}\n\n")
        
        input_bits = 12  # Default, or set dynamically if available
        f.write(f"parameter taps = {len(fixed_point_coeffs)};\n")
        f.write(f"parameter input_size = {12};\n")
        output_size = 32 + input_bits + math.ceil(np.log2(len(fixed_point_coeffs)))
        f.write(f"parameter output_size = {output_size};\n")
        
        # Write parameter declarations in copy-paste friendly format
        f.write("// FIR coefficients (51 taps) - 32-bit coefficients\n")
        
        # Group coefficients in sets of 4 for better readability
        for i in range(0, len(fixed_point_coeffs), 4):
            line = "parameter signed [31:0] "
            params = []
            for j in range(4):
                if i + j < len(fixed_point_coeffs):
                    coeff_val = int(fixed_point_coeffs[i + j])
                    if coeff_val < 0:
                        hex_val = (coeff_val + 2**32) % (2**32)
                    else:
                        hex_val = coeff_val
                    params.append(f"h{i+j:<2} = 32'h{hex_val:08X}")
            line += ", ".join(params) + ";\n"
            f.write(line)
        
        f.write("\n")
        
        f.write("reg [input_size-1:0] FIR [1:taps-1];\n")
        f.write("wire signed [11:0] data_in_signed = data_in - 12'd2048;\n")
        
        # Write MAC operation in copy-paste friendly format
        f.write("// Combinational MAC operation\n")
        f.write("wire signed [output_size-1:0] mac_result;\n")
        f.write("assign mac_result = ")
        
        # Write MAC terms
        mac_terms = []
        mac_terms.append("h0  * data_in_signed")
        for i in range(1, len(fixed_point_coeffs)):
            mac_terms.append(f"h{i:<2} * FIR[{i}]")
        
        # Format MAC operation with proper line breaks
        for i, term in enumerate(mac_terms):
            if i == 0:
                f.write(f"{term} +\n")
            elif i == len(mac_terms) - 1:
                f.write(f"                        {term};\n")
            else:
                f.write(f"                        {term} +\n")

# ...existing code...

    # Calculate some statistics
    max_coeff = np.max(np.abs(fir_coefficients))
    utilization = max_coeff * scale_factor / (2**31 - 1) * 100
    snr_db = 20 * np.log10(scale_factor) - 20 * np.log10(np.sqrt(np.mean(quantization_error**2)))
    
    print(f"\n32-bit Fixed-Point Analysis:")
    print(f"Scale Factor: {scale_factor}")
    print(f"Maximum coefficient magnitude: {max_coeff:.8f}")
    print(f"Dynamic range utilization: {utilization:.1f}%")
    print(f"Quantization SNR: {snr_db:.1f} dB")
    print(f"RMS quantization error: {np.sqrt(np.mean(quantization_error**2)):.2e}")
    
    print(f"\nCoefficients saved to 'fir_coefficients_32bit.txt'")
    print(f"Frequency response plot saved to 'fir_filter_response_32bit.png'")
    
    return fir_coefficients, fixed_point_coeffs, frequencies, h, h_fixed

if __name__ == "__main__":
    coeffs, fixed_coeffs, freq, response_float, response_fixed = design_fir_filter()