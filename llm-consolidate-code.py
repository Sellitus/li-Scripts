import os
import sys
import argparse
from collections import defaultdict
from pathlib import Path
import fnmatch

def detect_language(folder_path):
    language_files = defaultdict(int)
    language_extensions = {
        'Python': ['.py'],
        'JavaScript': ['.js', '.jsx'],
        'Java': ['.java'],
        'C++': ['.cpp', '.hpp', '.h', '.cc', '.cxx'],
        'C#': ['.cs'],
        'Ruby': ['.rb'],
        'Go': ['.go'],
        'PHP': ['.php'],
        'TypeScript': ['.ts', '.tsx'],
        'Swift': ['.swift'],
        'Kotlin': ['.kt', '.kts'],
        'Rust': ['.rs'],
        'HTML': ['.html', '.htm'],
        'CSS': ['.css'],
        'Shell': ['.sh', '.bash'],
        'Scala': ['.scala'],
        'Perl': ['.pl', '.pm'],
        'Dart': ['.dart'],
        'Lua': ['.lua']
    }

    excluded_dirs = get_excluded_directories(folder_path)

    for root, dirs, files in os.walk(folder_path):
        # Modify dirs in-place to skip excluded directories
        dirs[:] = [d for d in dirs if os.path.join(root, d) not in excluded_dirs]
        for file in files:
            _, ext = os.path.splitext(file)
            for language, exts in language_extensions.items():
                if ext.lower() in exts:
                    language_files[language] += 1

    if not language_files:
        return None

    primary_language = max(language_files, key=language_files.get)
    return primary_language

def get_excluded_directories(folder_path):
    # Common directories to exclude
    common_excludes = [
        'venv', 'env', '.env',
        '__pycache__', 'node_modules', 'build',
        'dist', '.git', '.svn', '.hg',
        'temp', 'tmp', 'out', 'target'
    ]

    excluded_dirs = set()
    for root, dirs, _ in os.walk(folder_path):
        for d in dirs:
            if d in common_excludes:
                excluded_path = os.path.join(root, d)
                excluded_dirs.add(os.path.abspath(excluded_path))
    return excluded_dirs

def parse_gitignore(folder_path):
    gitignore_path = os.path.join(folder_path, '.gitignore')
    patterns = []
    if os.path.isfile(gitignore_path):
        with open(gitignore_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    patterns.append(line)
    return patterns

def is_ignored(path, patterns, folder_path):
    relative_path = os.path.relpath(path, folder_path)
    for pattern in patterns:
        if fnmatch.fnmatch(relative_path, pattern) or fnmatch.fnmatch(os.path.basename(path), pattern):
            return True
    return False

def get_language_extensions(primary_language):
    language_extensions = {
        'Python': ['.py'],
        'JavaScript': ['.js', '.jsx'],
        'Java': ['.java'],
        'C++': ['.cpp', '.hpp', '.h', '.cc', '.cxx'],
        'C#': ['.cs'],
        'Ruby': ['.rb'],
        'Go': ['.go'],
        'PHP': ['.php'],
        'TypeScript': ['.ts', '.tsx'],
        'Swift': ['.swift'],
        'Kotlin': ['.kt', '.kts'],
        'Rust': ['.rs'],
        'HTML': ['.html', '.htm'],
        'CSS': ['.css'],
        'Shell': ['.sh', '.bash'],
        'Scala': ['.scala'],
        'Perl': ['.pl', '.pm'],
        'Dart': ['.dart'],
        'Lua': ['.lua']
    }
    return language_extensions.get(primary_language, [])

def collect_code_files(folder_path, extensions, excluded_dirs, gitignore_patterns):
    code_files = []
    for root, dirs, files in os.walk(folder_path):
        # Exclude directories
        dirs[:] = [d for d in dirs if os.path.abspath(os.path.join(root, d)) not in excluded_dirs]
        for file in files:
            filepath = os.path.join(root, file)
            if is_ignored(filepath, gitignore_patterns, folder_path):
                continue
            _, ext = os.path.splitext(file)
            if ext.lower() in extensions:
                code_files.append(filepath)
    return code_files

def write_consolidated_file(code_files, output_file):
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for file in code_files:
            outfile.write(f'\n\n\n\n===== {file} =====\n')
            try:
                with open(file, 'r', encoding='utf-8', errors='ignore') as infile:
                    for idx, line in enumerate(infile, 1):
                        outfile.write(f'{idx:4}: {line}')
            except Exception as e:
                outfile.write(f'Error reading file: {e}\n')
            outfile.write('\n\n')

def get_excluded_dirs_with_gitignore(folder_path):
    excluded_dirs = get_excluded_directories(folder_path)
    gitignore_patterns = parse_gitignore(folder_path)
    return excluded_dirs, gitignore_patterns

def count_tokens(text):
    # Simple tokenization: split text on whitespace and punctuation
    import re
    tokens = re.findall(r'\w+|\S', text)
    return len(tokens)

def main():
    parser = argparse.ArgumentParser(description='Consolidate code files into a single text file with line numbers, excluding specified directories and gitignored files.')
    parser.add_argument('folder_path', type=str, help='Path to the project folder')
    args = parser.parse_args()

    folder_path = args.folder_path

    if not os.path.isdir(folder_path):
        print(f'Error: {folder_path} is not a valid directory.')
        sys.exit(1)

    primary_language = detect_language(folder_path)

    if not primary_language:
        print('Could not detect the primary programming language.')
        sys.exit(1)

    print(f'Detected primary language: {primary_language}')

    extensions = get_language_extensions(primary_language)

    if not extensions:
        print(f'No extensions found for language: {primary_language}')
        sys.exit(1)

    excluded_dirs, gitignore_patterns = get_excluded_dirs_with_gitignore(folder_path)

    code_files = collect_code_files(folder_path, extensions, excluded_dirs, gitignore_patterns)

    if not code_files:
        print('No code files found in the specified directory.')
        sys.exit(1)

    output_file = os.path.join(os.getcwd(), f'consolidated_code.{os.path.basename(folder_path)}.{primary_language.lower()}.txt')
    write_consolidated_file(code_files, output_file)

    # Count and output the number of tokens in the final file
    with open(output_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    num_tokens = count_tokens(content)

    print(f'The consolidated file contains {num_tokens} tokens.')
    print(f'Consolidated file created at: {output_file}')

if __name__ == '__main__':
    main()