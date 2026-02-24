import yaml
import re
import os
from pathlib import Path
import argparse

# === CONFIGURATION: Script location awareness ===

# Get directory of where this script lives
SCRIPT_DIR = Path(__file__).parent.resolve()

# Get location of the root of the repo
REPO_ROOT = SCRIPT_DIR.parents[3]

# Load config relative to script location
CONFIG_FILE = SCRIPT_DIR / 'sanitization-config.yaml'

def load_config(config_file):
    """ Load the YAML configuration file. """
    with open(config_file, 'r') as file:
        config = yaml.safe_load(file)
        
    # Make paths absolute if they're relative
    if not Path(config['output_directory']).is_absolute():
        config['output_directory'] = str(SCRIPT_DIR / config['output_directory'])
        
    return config
    
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

def sanitize_content_regex(content, regex_rules):
    """ Apply regex-based pattern replacements to the content. """
    sanitized = content
    replacements_made = {}

    for rule in regex_rules:
        pattern = rule['pattern']
        replacement = rule['replacement']
        description = rule.get('description', pattern)

        sanitized, count = re.subn(pattern, replacement, sanitized, flags=re.IGNORECASE)
        if count > 0:
            replacements_made[description] = count

    return sanitized, replacements_made

def sanitize_file(input_file, output_dir, replacements, regex_replacements=None):
    """ Sanitize a single PowerShell file from my work scripts. """
    # Read the original file
    print(f"\nReading file: {input_file}")
    with open(input_file, 'r', encoding='utf-8') as file:
        original_content = file.read()
        
    print("Applying sanitization...")
    sanitized_content, replacements_made = sanitize_content(original_content, replacements)

    # Apply regex-based replacements after literal ones
    regex_replacements_made = {}
    if regex_replacements:
        sanitized_content, regex_replacements_made = sanitize_content_regex(sanitized_content, regex_replacements)

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
        print("Literal replacements made:")
        for original, count in replacements_made.items():
            print(f"  {original} → {replacements[original]} (replaced {count} times)")
    else:
        print("No literal replacements were made.")

    if regex_replacements_made:
        print("Regex replacements made:")
        for description, count in regex_replacements_made.items():
            print(f"  [{description}] (replaced {count} times)")
    elif regex_replacements:
        print("No regex replacements were made.")
    
    return output_file

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description="Sanitize PowerShell Scripts")
    parser.add_argument('--config', default=str(CONFIG_FILE), help="Path to config file (absolute)")
    parser.add_argument('--input-dir', default=str(REPO_ROOT / 'Windows/RSM-related/'), help="Directory containing PowerShell scripts to sanitize")
    parser.add_argument('--output-dir', help="Override output directory from config file")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print(" PowerShell Script Sanitization Tool ")
    print("=" * 60)
    
    # Load configuration
    config = load_config(args.config)
    replacements = config['replacements']
    output_dir = config['output_directory']
    regex_replacements = config.get('regex_replacements', [])

    print(f"\nLoaded: {len(replacements)} literal sanitization rules.")
    print(f"Loaded: {len(regex_replacements)} regex sanitization rules.")
    print(f"Output directory: {output_dir}.")
    
    # Iterate through files to sanitize
    base_dir = REPO_ROOT / 'Windows/RSM-related'
    
    print(f"\n📂 Scanning directory (recursive): {base_dir}")
    
    for ps1_file in base_dir.rglob('*.ps1'):
        print(f"Processing file: {ps1_file.name}")
        sanitize_file(str(ps1_file), output_dir, replacements, regex_replacements)
    
    
    # for item in os.listdir(base_dir):
            
    #     full_item_path = os.path.join(base_dir, item)
            
    #     # print(f"\n{"File - " + item + "\nFull path: " + full_item_path if os.path.isfile (os.path.join(base_dir, item)) else "Directory" if os.path.isdir(os.path.join(base_dir, item)) else "Unknown"}")
        
    #     file_extension = Path(item).suffix
    #     # print("File extension:", file_extension if file_extension else "N/A")
        
    #     # Confirm only PowerShell files are processed
    #     if file_extension.lower() != '.ps1':
    #         continue
    #     else:
    #         # Sanitize the test file
    #         print(f"Processing file: {item}")
    #         sanitize_file(full_item_path, output_dir, replacements)
    
    # # Harcoded test file
    # test_file = Path('C:\\Users\\E095713\\Documents\\Programming\\PowerShell\\my-scripts\\Windows\\RSM-related\\PnP\\Lock-SourceSite.ps1')
    
    print("=" * 60)
    print(" Sanitization complete! ")
    print("=" * 60)
