import yaml

# Read the YAML file
with open('sanitization-config.yaml', 'r') as file:
    config = yaml.safe_load(file)
    
# Print what we loaded
print("Replacements found:")
for original, replacement in config['replacements'].items():
    print(f" {original} → {replacement}")
    
print ("\nOutput directory: ", config['output_directory'])