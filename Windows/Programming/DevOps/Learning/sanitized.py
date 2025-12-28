import yaml
import os
from pathlib import Path

def load_config(config_file):
    """ Load the YAML configuration file. """
    with open(config_file, 'r') as file:
        return yaml.safe_load(file)
    
def sanitize_content(content, replacements):
    """ Apply all replacements to the content. """
    sanitized = content
    
    # Track what was replaced for reporting
    replacements_made = {}
    
    for original, replacement in replacements.items():
        if original in sanitized:
            count = sanitized.count(original)
            sanitized = sanitized.replace(original, replacement)
            replacements_made[original] = count
            
    return sanitized, replacements_made

def sanitize_file(input_file, output_dir, replacements):
    """ Sanitize a single PowerShell file from my work scripts. """
    # Read the original file
    print(f"\nReading file: {input_file}")
    with open(input_file, 'r', encoding='utf-8') as file:
        original_content = file.read()
        
    print("Applying sanitization...")
    sanitized_content, replacements_made = sanitize_content(original_content, replacements)
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Write sanitized file with the same name
    file_name = os.path.basename(input_file)
    output_file = os.path.join(output_dir, file_name)
    
    with open(output_file, 'w', encoding='utf-8') as file:
        file.write(sanitized_content)
    
    print(f"Sanitized file saved to: {output_file}")
    
    # Print replacements made if any
    if replacements_made:
        print("Replacements made:")
        for original, count in replacements_made.items():
            print(f" {original} → {replacements[original]} (replaced {count} times)")
    else:
        print("No replacements were made.")
    
    return output_file

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print(" PowerShell Script Sanitization Tool ")
    print("=" * 60)
    
    # Load configuration
    config = load_config('sanitization-config.yaml')
    replacements = config['replacements']
    output_dir = config['output_directory']
    
    print(f"\nLoaded: {len(replacements)} sanitization rules.")
    print(f"Output directory: {output_dir}.")
    
    # Iterate through files to sanitize
    base_dir = Path('C:\\Users\\E095713\\Documents\\Programming\\PowerShell\\my-scripts\\Windows\\RSM-related\\PnP')
    
    for item in os.listdir(base_dir):
            
        full_item_path = os.path.join(base_dir, item)
            
        # print(f"\n{"File - " + item + "\nFull path: " + full_item_path if os.path.isfile (os.path.join(base_dir, item)) else "Directory" if os.path.isdir(os.path.join(base_dir, item)) else "Unknown"}")
        
        file_extension = Path(item).suffix
        # print("File extension:", file_extension if file_extension else "N/A")
        
        # Confirm only PowerShell files are processed
        if file_extension.lower() != '.ps1':
            continue
        else:
            # Sanitize the test file
            print(f"Processing file: {item}")
            sanitize_file(full_item_path, output_dir, replacements)
    
    # # Harcoded test file
    # test_file = Path('C:\\Users\\E095713\\Documents\\Programming\\PowerShell\\my-scripts\\Windows\\RSM-related\\PnP\\Lock-SourceSite.ps1')
    
    print("=" * 60)
    print(" Sanitization complete! ")
    print("=" * 60)
