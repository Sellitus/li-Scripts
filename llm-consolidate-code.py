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
from typing import List, Dict, Set, Tuple, Callable, Union
import humanize
try:
    import tiktoken
    TIKTOKEN_AVAILABLE = True
except ImportError:
    TIKTOKEN_AVAILABLE = False

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

def process_mini_output(lines: List[str]) -> str:
    """Process file content to only include function definitions and preserve line numbers."""
    result = []
    in_py_function = False
    in_bracket_function = False
    py_function_indent = -1
    bracket_depth = 0
    
    # Common function definition patterns for different languages
    py_fn_pattern = r'^\s*def\s+\w+\s*\('  # Python
    bracket_fn_patterns = [
        r'^\s*function\s+\w+\s*\(',  # JavaScript
        r'^\s*\w+\s+\w+\s*\([^)]*\)\s*{',  # C/C++/Java/C#
        r'^\s*public|private|protected\s+\w+\s+\w+\s*\(',  # Java/C# methods
    ]
    
    # Check if a line is a Python function definition
    def is_py_function_def(line: str) -> bool:
        return bool(re.search(py_fn_pattern, line))
    
    # Check if a line is a bracket-based function definition
    def is_bracket_function_def(line: str) -> bool:
        return any(re.search(pattern, line) for pattern in bracket_fn_patterns)
    
    # Determine indentation level of a line
    def get_indent_level(line: str) -> int:
        return len(line) - len(line.lstrip())
    
    for idx, line in enumerate(lines, 1):
        strip_line = line.strip()
        
        # Always include empty lines with their line numbers
        if not strip_line:
            result.append(f"{idx:4}: {line}")
            continue
        
        # Track brackets for languages using them
        open_brackets = line.count('{')
        close_brackets = line.count('}')
        
        # Python function detection and handling
        if ':' in line and is_py_function_def(line):
            # Start of a Python function
            in_py_function = True
            py_function_indent = get_indent_level(line)
            result.append(f"{idx:4}: {line}")
            continue
        
        # Handle Python function body based on indentation
        if in_py_function:
            curr_indent = get_indent_level(line)
            
            # Check if we're exiting the function (less or equal indentation than function def)
            # Skip empty lines and comments when checking indentation
            if strip_line and curr_indent <= py_function_indent and not strip_line.startswith('#'):
                in_py_function = False
                result.append(f"{idx:4}: {line}")
                continue
            
            # We're in the function body - output empty line to maintain line numbers
            result.append(f"{idx:4}: ")
            continue
        
        # Handle bracket-based languages function detection
        if not in_bracket_function and is_bracket_function_def(line) and '{' in line:
            in_bracket_function = True
            bracket_depth = open_brackets - close_brackets
            result.append(f"{idx:4}: {line}")
            continue
        
        # Handle bracket-based function body
        if in_bracket_function:
            # Update bracket depth
            bracket_depth += open_brackets - close_brackets
            
            # If we've closed all brackets, we've exited the function
            if bracket_depth <= 0:
                in_bracket_function = False
                result.append(f"{idx:4}: {line}")
                continue
            
            # We're in the function body - output empty line
            result.append(f"{idx:4}: ")
            continue
        
        # Include all non-function lines normally
        result.append(f"{idx:4}: {line}")
    
    return '\n'.join(result)

def write_output(processed_files: List[Tuple[str, str]], stats: CodeStats, 
                output_file: str, markdown_output: bool, compress: bool, mini: bool = False):
    content = f"# Code Analysis Report\n\n{str(stats)}\n\n" if markdown_output else str(stats)
    
    for filepath, file_content in processed_files:
        separator = "\n\n## " if markdown_output else "\n\n===== "
        content += f"{separator}{filepath} =====\n\n"
        
        if markdown_output:
            content += "```\n"
        
        lines = file_content.splitlines()
        
        if mini:
            # Process lines to keep only function definitions and preserve line numbers
            content += process_mini_output(lines)
        else:
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

def count_tokens_simple(text: str) -> int:
    """Count tokens using a basic approach (words and non-whitespace symbols)."""
    return len(re.findall(r'\w+|\S', text))

def count_tokens_improved(text: str) -> int:
    """
    Count tokens using a heuristic approximation of how LLMs tokenize text.
    This implementation provides a better estimate than simple word splitting.
    """
    # Handle common punctuation and special characters as separate tokens
    text = re.sub(r'([.,!?;:()[\]{}"\'])', r' \1 ', text)
    
    # Handle contractions specially
    text = re.sub(r"([a-zA-Z])'([a-zA-Z])", r"\1 ' \2", text)
    
    # Split on whitespace to get raw tokens
    raw_tokens = text.split()
    
    total_tokens = 0
    for token in raw_tokens:
        # Count numbers as single tokens
        if re.match(r'^\d+$', token):
            total_tokens += 1
            continue
            
        # Count individual punctuation as single tokens
        if re.match(r'^[.,!?;:()[\]{}"\']$', token):
            total_tokens += 1
            continue
            
        # Handle tokens with mixed alphanumerics
        if re.search(r'[a-zA-Z0-9]', token):
            # Count uppercase runs as potential separate tokens (e.g., "GPT" -> "G", "P", "T")
            uppercase_runs = len(re.findall(r'[A-Z]{2,}', token))
            if uppercase_runs > 0:
                # Adjust for uppercase runs
                total_tokens += len(token) // 2 + 1
            else:
                # For regular words, estimate based on length (an approximation)
                if len(token) <= 4:
                    total_tokens += 1
                else:
                    # Longer words might be split into subwords by tokenizers
                    total_tokens += max(1, len(token) // 4 + 1)
        else:
            # Handle other symbols
            total_tokens += len(token)
    
    return total_tokens

def count_tokens_tiktoken(text: str, model: str = "gpt-4.5") -> int:
    """
    Count tokens using the OpenAI tiktoken library, which provides
    the most accurate token counting for GPT models.
    """
    if not TIKTOKEN_AVAILABLE:
        print("Warning: tiktoken not installed. Using improved tokenization method instead.")
        return count_tokens_improved(text)
    
    try:
        encoding = tiktoken.encoding_for_model(model)
        return len(encoding.encode(text))
    except Exception as e:
        print(f"Error using tiktoken: {e}. Falling back to improved tokenization method.")
        return count_tokens_improved(text)

def count_tokens(text: str, method: str = "improved", model: str = "gpt-4.5") -> int:
    """
    Count tokens using the specified method.
    
    Args:
        text: The text to tokenize
        method: One of "simple", "improved", or "tiktoken"
        model: The model to use for tiktoken (default: "gpt-4.5")
    
    Returns:
        The number of tokens
    """
    if method == "simple":
        return count_tokens_simple(text)
    elif method == "tiktoken":
        return count_tokens_tiktoken(text, model)
    else:  # Default to improved
        return count_tokens_improved(text)

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
    parser.add_argument('--mini', action='store_true',
                       help='Only include function definitions, not implementations, while preserving line numbers')
    parser.add_argument('--tokenizer', type=str, 
                       choices=['simple', 'improved', 'tiktoken'], default='tiktoken',
                       help='Tokenization method to use for token counting: simple (basic word count), '
                            'improved (heuristic approximation), or tiktoken (exact GPT tokenization, requires package) '
                            '(default: tiktoken)')
    parser.add_argument('--model', type=str, default='gpt-4.5',
                       help='Model to use for tiktoken tokenization when --tokenizer=tiktoken (default: gpt-4.5)')
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
        args.markdown, args.compress, args.mini
    )

    # Count tokens in final output
    with open(output_file, 'r', encoding='utf-8') if not args.compress else \
         gzip.open(output_file, 'rt', encoding='utf-8') as f:
        content = f.read()
        
        # Use selected tokenization method
        num_tokens = count_tokens(content, method=args.tokenizer, model=args.model)
        
        # Get counts using other methods if tiktoken is available
        if args.tokenizer == 'tiktoken' and TIKTOKEN_AVAILABLE:
            simple_count = count_tokens_simple(content)
            improved_count = count_tokens_improved(content)
            tiktoken_count = num_tokens
            
            # Calculate differences between methods
            simple_diff = ((simple_count - tiktoken_count) / tiktoken_count) * 100
            improved_diff = ((improved_count - tiktoken_count) / tiktoken_count) * 100
        
        file_size = os.path.getsize(output_file)
        file_size_str = humanize.naturalsize(file_size, binary=True)

    print(stats)
    
    print(f'\nOutput Statistics:')
    tokenizer_method = f" ({args.tokenizer}{' tokenizer' if args.tokenizer != 'tiktoken' else f', using {args.model} model'})"
    print(f'Token Count: {num_tokens:,}{tokenizer_method}')
    
    # Show comparison of different tokenization methods if tiktoken is available
    if args.tokenizer == 'tiktoken' and TIKTOKEN_AVAILABLE:
        print(f'  Simple tokenizer: {simple_count:,} tokens ({simple_diff:+.1f}%)')
        print(f'  Improved tokenizer: {improved_count:,} tokens ({improved_diff:+.1f}%)')
    
    print(f'File Size: {file_size_str}')
    print(f'Output File: {output_file}\n')
    
    if args.tokenizer == 'tiktoken' and not TIKTOKEN_AVAILABLE:
        print("Note: For more accurate token counting, install tiktoken: pip install tiktoken")

if __name__ == '__main__':
    main()
