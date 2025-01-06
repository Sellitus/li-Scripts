import os
import sys
import argparse
from collections import defaultdict
from pathlib import Path
import fnmatch
import tqdm
import concurrent.futures
import pygments
from pygments import formatters, lexers
import markdown
import gzip
import re
from typing import List, Dict, Set, Tuple
import humanize

class CodeStats:
    def __init__(self):
        self.total_lines = 0
        self.code_lines = 0
        self.comment_lines = 0
        self.blank_lines = 0
        self.file_count = 0
        self.total_size = 0
        
        self.language_extensions = {
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

    def update(self, lines: List[str], file_size: int):
        self.file_count += 1
        self.total_size += file_size
        self.total_lines += len(lines)
        
        for line in lines:
            stripped = line.strip()
            if not stripped:
                self.blank_lines += 1
            elif stripped.startswith(('#', '//', '/*', '*', '<!--')):
                self.comment_lines += 1
            else:
                self.code_lines += 1

    def __str__(self):
        return f"""
Code Statistics:
---------------
Total Files: {self.file_count}
Total Size: {humanize.naturalsize(self.total_size)}
Total Lines: {self.total_lines:,}
Code Lines: {self.code_lines:,}
Comment Lines: {self.comment_lines:,}
Blank Lines: {self.blank_lines:,}
"""

def detect_languages(folder_path: str) -> Dict[str, int]:
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
        dirs[:] = [d for d in dirs if os.path.join(root, d) not in excluded_dirs]
        for file in files:
            _, ext = os.path.splitext(file)
            for language, exts in language_extensions.items():
                if ext.lower() in exts:
                    language_files[language] += 1

    return dict(sorted(language_files.items(), key=lambda x: x[1], reverse=True))

def get_excluded_directories(folder_path: str) -> Set[str]:
    common_excludes = {
        'venv', 'env', '.env',
        '__pycache__', 'node_modules', 'build',
        'builds',
        'dist', '.git', '.svn', '.hg',
        'temp', 'tmp', 'out', 'target'
    }

    excluded_dirs = set()
    for root, dirs, _ in os.walk(folder_path):
        for d in dirs:
            if d in common_excludes:
                excluded_path = os.path.join(root, d)
                excluded_dirs.add(os.path.abspath(excluded_path))
    return excluded_dirs

def parse_gitignore(folder_path: str) -> List[str]:
    gitignore_path = os.path.join(folder_path, '.gitignore')
    patterns = []
    if os.path.isfile(gitignore_path):
        with open(gitignore_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    patterns.append(line)
    return patterns

def is_ignored(path: str, patterns: List[str], folder_path: str) -> bool:
    relative_path = os.path.relpath(path, folder_path)
    return any(fnmatch.fnmatch(relative_path, pattern) or 
              fnmatch.fnmatch(os.path.basename(path), pattern) 
              for pattern in patterns)

def get_language_extensions(languages: List[str]) -> List[str]:
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
    
    extensions = []
    for lang in languages:
        if lang in language_extensions:
            extensions.extend(language_extensions[lang])
    return extensions

def process_file(args: Tuple[str, List[str], bool]) -> Tuple[str, str, int, List[str]]:
    filepath, extensions, prettify = args
    if not any(filepath.lower().endswith(ext) for ext in extensions):
        return filepath, "", 0, []
        
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            lines = content.splitlines()
            
        if prettify:
            try:
                lexer = lexers.get_lexer_for_filename(filepath)
                formatter = formatters.TerminalFormatter()
                content = pygments.highlight(content, lexer, formatter)
            except:
                pass  # If prettifying fails, use original content
                
        return filepath, content, os.path.getsize(filepath), lines
    except Exception as e:
        return filepath, f"Error reading file: {e}\n", 0, []

def collect_and_process_files(folder_path: str, extensions: List[str], excluded_dirs: Set[str], 
                            gitignore_patterns: List[str], prettify: bool) -> Tuple[List[Tuple[str, str]], CodeStats]:
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
    code_files = []
    stats = CodeStats()
    
    for root, dirs, files in os.walk(folder_path):
        dirs[:] = [d for d in dirs if os.path.abspath(os.path.join(root, d)) not in excluded_dirs]
        for file in files:
            filepath = os.path.join(root, file)
            if not is_ignored(filepath, gitignore_patterns, folder_path):
                code_files.append(filepath)
                
    # Count the number of each language code file by the extension of the file
    language_counts = defaultdict(int)
    for file in code_files:
        _, ext = os.path.splitext(file)
        for language, exts in language_extensions.items():
            if ext.lower() in exts:
                language_counts[language] += 1

    print("\nLanguage file counts:")
    for language, count in language_counts.items():
        print(f"{language}: {count} files")

    processed_files = []
    with concurrent.futures.ThreadPoolExecutor() as executor:
        args = [(f, extensions, prettify) for f in code_files]
        with tqdm.tqdm(total=len(code_files), desc="Processing files") as pbar:
            for filepath, content, size, lines in executor.map(process_file, args):
                if content:  # Only include files with content
                    processed_files.append((filepath, content))
                    stats.update(lines, size)
                pbar.update(1)

    return processed_files, stats

def write_output(processed_files: List[Tuple[str, str]], stats: CodeStats, 
                output_file: str, markdown_output: bool, compress: bool):
    content = f"# Code Analysis Report\n\n{str(stats)}\n\n" if markdown_output else str(stats)
    
    for filepath, file_content in processed_files:
        separator = "\n\n## " if markdown_output else "\n\n===== "
        content += f"{separator}{filepath} =====\n\n"
        
        if markdown_output:
            content += "```\n"
        
        lines = file_content.splitlines()
        content += '\n'.join(f"{idx:4}: {line}" for idx, line in enumerate(lines, 1))
        
        if markdown_output:
            content += "\n```"
    
    if compress:
        output_file += '.gz'
        with gzip.open(output_file, 'wt', encoding='utf-8') as f:
            f.write(content)
    else:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
            
    return output_file

def count_tokens(text: str) -> int:
    return len(re.findall(r'\w+|\S', text))

def main():
    parser = argparse.ArgumentParser(
        description='Consolidate code files into a single text file with advanced features.')
    parser.add_argument('folder_path', type=str, help='Path to the project folder')
    parser.add_argument('--languages', type=str, nargs='+', 
                       help='Specific languages to include (default: auto-detect)')
    parser.add_argument('--prettify', action='store_true', 
                       help='Enable syntax highlighting in output')
    parser.add_argument('--markdown', action='store_true', 
                       help='Output in Markdown format')
    parser.add_argument('--compress', action='store_true', 
                       help='Compress output file using gzip')
    args = parser.parse_args()

    if not os.path.isdir(args.folder_path):
        print(f'Error: {args.folder_path} is not a valid directory.')
        sys.exit(1)
        
    if args.folder_path == '.':
        args.folder_path = os.getcwd()
    else:
        args.folder_path = os.path.abspath(args.folder_path)
        
    # Detect languages and show statistics
    detected_languages = detect_languages(args.folder_path)
    print("\nDetected languages:")
    for lang, count in detected_languages.items():
        print(f"{lang}: {count} files")

    # Use specified languages or all detected ones
    languages = args.languages if args.languages else list(detected_languages.keys())
    if not languages:
        print('No supported programming languages detected.')
        sys.exit(1)

    extensions = get_language_extensions(languages)
    if not extensions:
        print(f'No extensions found for languages: {", ".join(languages)}')
        sys.exit(1)

    excluded_dirs = get_excluded_directories(args.folder_path)
    gitignore_patterns = parse_gitignore(args.folder_path)

    # Process files with progress bar and parallel processing
    processed_files, stats = collect_and_process_files(
        args.folder_path, extensions, excluded_dirs, 
        gitignore_patterns, args.prettify
    )

    if not processed_files:
        print('No code files found in the specified directory.')
        sys.exit(1)

    # Generate output filename
    base_name = os.path.basename(args.folder_path)
    lang_suffix = '-'.join(lang.lower() for lang in languages[:1])
    output_file = os.path.join(
        os.getcwd(), 
        f'consolidated_code.{base_name}.{lang_suffix}'
    )
    if args.markdown:
        output_file += '.md'
    else:
        output_file += '.txt'

    # Write output with chosen format and compression
    output_file = write_output(
        processed_files, stats, output_file,
        args.markdown, args.compress
    )

    # Count tokens in final output
    with open(output_file, 'r', encoding='utf-8') if not args.compress else \
         gzip.open(output_file, 'rt', encoding='utf-8') as f:
        content = f.read()
        num_tokens = count_tokens(content)
        file_size = os.path.getsize(output_file)
        file_size_str = humanize.naturalsize(file_size, binary=True)

    print(stats)
    
    print(f'\nOutput Statistics:')
    print(f'Token Count: {num_tokens:,}')
    print(f'File Size: {file_size_str}')
    print(f'Output File: {output_file}\n')

if __name__ == '__main__':
    main()
