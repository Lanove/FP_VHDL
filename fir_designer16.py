import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
import math

def design_fir_filter():
    # Filter specifications
    fs = 25000  # Sampling frequency in Hz
    fc = 1100   # Cutoff frequency in Hz
    
    # Normalized cutoff frequency (0 to 1, where 1 is Nyquist frequency)
    nyquist = fs / 2
    normalized_cutoff = fc / nyquist * 0.85
    
    # Filter order (higher order = sharper cutoff, more taps)
    filter_order = 51  # Odd number for symmetric filter
    
    # Design FIR filter using window method (Cosine window, highpass)
    fir_coefficients = signal.firwin(filter_order, normalized_cutoff, window='hamming', pass_zero='highpass')
    
    # Print some general filter information
    print(f"FIR Filter Design:")
    print(f"Sampling Rate: {fs} Hz")
    print(f"Cutoff Frequency: {fc} Hz")
    print(f"Filter Order: {filter_order}")
    print(f"Number of Taps: {len(fir_coefficients)}")
    print(f"Normalized Cutoff: {normalized_cutoff:.4f}")
    
    # Show the first 10 floating-point coefficients
    print(f"\nFIR Coefficients (floating point, first 10):")
    for i in range(min(10, len(fir_coefficients))):
        print(f"h[{i}] = {fir_coefficients[i]:.8f}")
    
    # Convert to 16-bit fixed-point for FPGA implementation
    # Scale coefficients to 16-bit signed integers
    scale_factor = 2**15 - 1  # Maximum value for 16-bit signed integer
    fixed_point_coeffs = np.round(fir_coefficients * scale_factor).astype(np.int64)
    
    # Clip values to 16-bit signed range and cast to int16
    fixed_point_coeffs = np.clip(fixed_point_coeffs, -2**15, 2**15 - 1).astype(np.int16)
    
    print(f"\nFixed-Point Coefficients (16-bit, first 10):")
    for i in range(len(fixed_point_coeffs)):
        coeff_val = int(fixed_point_coeffs[i])
        # Two's complement 16-bit
        if coeff_val < 0:
            hex_val = (coeff_val + 2**16) % (2**16)
        else:
            hex_val = coeff_val
        print(f"coeff[{i:3d}] = 16'h{hex_val:04X};  // {fir_coefficients[i]:12.8f}")
    
    # Calculate frequency response using original floating-point coefficients
    w, h = signal.freqz(fir_coefficients, worN=8000)
    frequencies = w * fs / (2 * np.pi)
    
    # Also compute response for fixed-point version
    # Convert fixed-point coeffs back to float for freqz
    normalized_fixed_coeffs = fixed_point_coeffs.astype(np.float64) / scale_factor
    w_fixed, h_fixed = signal.freqz(normalized_fixed_coeffs, worN=8000)
    
    # Plot frequency response comparison
    plt.figure(figsize=(15, 10))
    
    # Magnitude response
    plt.subplot(1, 2, 1)
    plt.plot(frequencies, 20 * np.log10(abs(h)), 'b-', label='Floating Point', linewidth=2)
    plt.plot(frequencies, 20 * np.log10(abs(h_fixed)), 'r--', label='16-bit Fixed Point', linewidth=1)
    plt.axvline(fc, color='g', linestyle='--', label=f'Cutoff: {fc} Hz')
    plt.axhline(-3, color='orange', linestyle='--', label='-3 dB')
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Magnitude (dB)')
    plt.title('FIR Filter Frequency Response - Magnitude Comparison')
    plt.grid(True)
    plt.legend()
    plt.xlim(0, 10000)
    
    # Phase response
    plt.subplot(1, 2, 2)
    plt.plot(frequencies, np.angle(h) * 180 / np.pi, 'b-', label='Floating Point', linewidth=2)
    plt.plot(frequencies, np.angle(h_fixed) * 180 / np.pi, 'r--', label='16-bit Fixed Point', linewidth=1)
    plt.axvline(fc, color='g', linestyle='--', label=f'Cutoff: {fc} Hz')
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Phase (degrees)')
    plt.title('FIR Filter Frequency Response - Phase Comparison')
    plt.grid(True)
    plt.legend()
    plt.xlim(0, 10000)
    
    plt.tight_layout()
    plt.savefig('fir_filter_response_16bit.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    # Compute quantization error
    quantization_error = fir_coefficients - normalized_fixed_coeffs
    
    # Calculate some statistics about the 16-bit fixed-point representation
    max_coeff    = np.max(np.abs(fir_coefficients))
    utilization  = max_coeff * scale_factor / (2**15 - 1) * 100
    snr_db       = 20 * np.log10(scale_factor) - 20 * np.log10(np.sqrt(np.mean(quantization_error**2)))
    
    print(f"\n16-bit Fixed-Point Analysis:")
    print(f"Scale Factor: {scale_factor}")
    print(f"Maximum coefficient magnitude: {max_coeff:.8f}")
    print(f"Dynamic range utilization: {utilization:.1f}%")
    print(f"Quantization SNR: {snr_db:.1f} dB")
    print(f"RMS quantization error: {np.sqrt(np.mean(quantization_error**2)):.2e}")
    
    # ...existing code...

    with open('fir_coefficients_16bit.txt', 'w') as f:
        f.write("CONSTANT coeffs : coeff_array_t := (\n")
        for i in range(len(fixed_point_coeffs)):
            coeff_val = int(fixed_point_coeffs[i])
            # Two's complement for 16 bits
            if coeff_val < 0:
                hex_val = (coeff_val + 2**16) % (2**16)
            else:
                hex_val = coeff_val

            # Add a comma only for all but the last item
            if i < len(fixed_point_coeffs) - 1:
                comma = ","
            else:
                comma = ""

            f.write(f"  {i} => x\"{hex_val:04X}\"{comma} -- {coeff_val:d}\n")

        f.write(");\n")

# ...existing code...
    
    print(f"\nCoefficients saved to 'fir_coefficients_16bit.txt'")
    print(f"Frequency response plot saved to 'fir_filter_response_16bit.png'")
    
    return fir_coefficients, fixed_point_coeffs, frequencies, h, h_fixed

if __name__ == "__main__":
    coeffs_float, coeffs_fixed_16, freq, response_float, response_fixed = design_fir_filter()