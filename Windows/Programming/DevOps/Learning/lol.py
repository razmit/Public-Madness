import os 
import itertools
from pathlib import Path
from termcolor import colored, cprint

def read_first_lines(file_path, n_lines):
    """ Read and return the first n lines of a file. """
    with open(file_path, 'r', encoding='utf-8') as file:
        lines = list(itertools.islice(file, n_lines))
    return lines

if __name__ == "__main__":
    print("Hello, DevOps Learning Script!")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    print("Current script directory:", script_dir)
    
    current_working_dir = os.getcwd()
    print("Current working directory:", current_working_dir)
    
    directory_to_iterate = input("Enter the directory path to iterate: ")
    first_lines_per_file = {}
    file_key_value = lambda f: cprint(f, 'green', attrs=['bold'])
    try:
        for item in os.listdir(directory_to_iterate):
            
            full_item_path = os.path.join(directory_to_iterate, item)
            
            print(f"\n{"File - " + item + "\nFull path: " + full_item_path if os.path.isfile (os.path.join(directory_to_iterate, item)) else "Directory" if os.path.isdir(os.path.join(directory_to_iterate, item)) else "Unknown"}")
            
            file_extension = Path(item).suffix
            print("File extension:", file_extension if file_extension else "N/A")
            
            if file_extension.lower() != '.ps1':
                continue
            else:
                new_values = {
                    item: read_first_lines(full_item_path, 5)
                }
                first_lines_per_file.update(new_values)
        
        for key, value in first_lines_per_file.items():
            print("\n" + "-"*40)
            print(f"\nFirst 5 lines of:")
            print(f"\n{file_key_value(key)}")
            for line in value:
                print(line.rstrip())
        
    except FileNotFoundError:
        print("The specified directory does not exist.")