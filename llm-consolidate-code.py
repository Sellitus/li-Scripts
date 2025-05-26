#!/usr/bin/env python3
"""
LLM Code Repository Analyzer - Optimized for minimal token usage
Consolidates repository code into a single file for LLM processing
"""

import os
import sys
import argparse
from collections import defaultdict, Counter
from pathlib import Path
import fnmatch
import re
from typing import List, Dict, Set, Tuple, Any, Optional
import gzip
import json
import time
import hashlib
import statistics
import unittest
from io import StringIO

# Check if tiktoken is available
try:
    import tiktoken
    TIKTOKEN_AVAILABLE = True
    # Use cl100k_base encoding (GPT-4 default)
    try:
        TOKENIZER = tiktoken.get_encoding("cl100k_base")
    except:
        TIKTOKEN_AVAILABLE = False
except ImportError:
    TIKTOKEN_AVAILABLE = False

# Optional imports
try:
    import tqdm
    TQDM_AVAILABLE = True
except ImportError:
    TQDM_AVAILABLE = False
    
try:
    import pygments
    from pygments import formatters, lexers
    PYGMENTS_AVAILABLE = True
except ImportError:
    PYGMENTS_AVAILABLE = False

# ANSI color codes
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'

def format_bytes(size):
    """Format bytes to human readable format."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size < 1024.0:
            return f"{size:.1f}{unit}"
        size /= 1024.0
    return f"{size:.1f}TB"

def format_number(num):
    """Format number with comma separators."""
    return f"{num:,}"

def estimate_tokens(text: str) -> int:
    """Estimate token count using tiktoken or fallback method."""
    if TIKTOKEN_AVAILABLE:
        return len(TOKENIZER.encode(text))
    else:
        # Improved fallback: More accurate GPT-style tokenization estimate
        # Count words and special characters
        words = len(re.findall(r'\b\w+\b', text))
        special_chars = len(re.findall(r'[^\w\s]', text))
        whitespace = len(re.findall(r'\s+', text))
        
        # GPT typically tokenizes:
        # - Words as ~1 token each
        # - Special characters often as separate tokens
        # - Whitespace is often merged with adjacent tokens
        estimated_tokens = words + (special_chars * 0.7) + (whitespace * 0.3)
        
        return max(1, int(estimated_tokens))

class CompressionLevel:
    """Define compression levels and their features."""
    
    LEVELS = {
        0: {
            'name': 'No Compression',
            'description': 'Original code preserved exactly as-is',
            'features': []
        },
        1: {
            'name': 'Light Compression',
            'description': 'Basic whitespace optimization',
            'features': [
                'Remove consecutive empty lines (keep max 1)',
                'Remove trailing whitespace',
                'Normalize line endings'
            ]
        },
        2: {
            'name': 'Moderate Compression',
            'description': 'Remove non-essential elements',
            'features': [
                'All Level 1 optimizations',
                'Remove standalone comment lines (keep TODO/FIXME)',
                'Compress large function bodies (>10 lines) to signatures',
                'Remove debug/print statements'
            ]
        },
        3: {
            'name': 'Aggressive Compression',
            'description': 'Remove documentation and tests',
            'features': [
                'All Level 2 optimizations',
                'Remove all docstrings',
                'Remove entire test functions/classes',
                'Remove type hints/annotations',
                'Compress class methods'
            ]
        },
        4: {
            'name': 'Maximum Compression',
            'description': 'Extreme size reduction',
            'features': [
                'All Level 3 optimizations',
                'Remove ALL comments',
                'Minify whitespace in code',
                'Remove optional syntax elements',
                'Abbreviate common patterns'
            ]
        }
    }
    
    @classmethod
    def get_description(cls, level: int) -> str:
        """Get formatted description for compression level."""
        if level not in cls.LEVELS:
            return "Invalid compression level"
            
        info = cls.LEVELS[level]
        desc = [f"{Colors.BOLD}{info['name']}{Colors.ENDC}: {info['description']}"]
        
        if info['features']:
            desc.append(f"{Colors.CYAN}Features:{Colors.ENDC}")
            for feature in info['features']:
                desc.append(f"  • {feature}")
                
        return '\n'.join(desc)

class FileClassifier:
    """Intelligently classify files based on their purpose and importance."""
    
    def __init__(self):
        # Core source code extensions only
        self.source_code_extensions = {
            # Major languages
            '.py', '.js', '.jsx', '.ts', '.tsx', '.java', '.cpp', '.hpp', '.c', '.h',
            '.cc', '.cxx', '.cs', '.rb', '.go', '.php', '.swift', '.kt', '.kts', 
            '.rs', '.scala', '.pl', '.pm', '.dart', '.lua', '.r', '.R', '.m', '.mm',
            '.f90', '.f95', '.jl', '.nim', '.v', '.zig', '.ex', '.exs', '.clj', 
            '.cljs', '.elm', '.hs', '.ml', '.fs', '.vb', '.pas', '.d', '.cr', 
            '.groovy',
            # Web
            '.html', '.htm', '.css', '.scss', '.sass', '.less', '.vue', '.svelte',
            # Shell
            '.sh', '.bash', '.zsh', '.fish', '.ps1', '.bat', '.cmd',
            # Data/Config as code
            '.sql', '.graphql', '.proto',
        }
        
        # Critical config files only (minimal set)
        self.important_config_patterns = {
            # Python
            'requirements.txt', 'setup.py', 'pyproject.toml', 'setup.cfg',
            # JavaScript/Node - only package.json, NOT lock files
            'package.json', 'tsconfig.json',
            # Build configs
            'Dockerfile', 'docker-compose.yml', 'docker-compose.yaml',
            '.dockerignore', 'Makefile', 'CMakeLists.txt',
            # CI/CD (only if in root or .github)
            '.github/workflows/*.yml', '.gitlab-ci.yml',
            # Documentation (only main ones)
            'README.md', 'README.rst', 'README.txt',
            # API specs
            'openapi.json', 'openapi.yaml', 'swagger.json', 'swagger.yaml',
        }
        
        # Strictly exclude these
        self.exclude_patterns = {
            # Lock files
            '*.lock', 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml',
            'poetry.lock', 'Pipfile.lock', 'composer.lock', 'Gemfile.lock',
            'Cargo.lock', 'packages.lock.json', 'bun.lockb',
            # Build artifacts
            '*.pyc', '*.pyo', '*.pyd', '*.so', '*.dylib', '*.dll', '*.class',
            '*.jar', '*.war', '*.o', '*.obj', '*.exe', '*.app',
            # Caches
            '*.cache', '*.log', '*.tmp', '*.temp', '*.swp', '*.swo',
            # Data files
            '*.db', '*.sqlite', '*.sqlite3', '*.csv', '*.dat',
            # Media
            '*.jpg', '*.jpeg', '*.png', '*.gif', '*.ico', '*.svg',
            '*.mp3', '*.mp4', '*.avi', '*.mov', '*.pdf', '*.doc', '*.docx',
            # Archives
            '*.zip', '*.tar', '*.gz', '*.bz2', '*.7z', '*.rar',
            # Min files
            '*.min.js', '*.min.css', '*.map',
            # OS
            '.DS_Store', 'Thumbs.db', 'desktop.ini',
        }
        
        # Directories to always exclude
        self.exclude_dirs = {
            # VCS
            '.git', '.svn', '.hg', '.bzr',
            # Dependencies
            'node_modules', 'bower_components', 'jspm_packages',
            'vendor', 'packages', 'libs', 'third_party',
            # Python
            '__pycache__', '.pytest_cache', '.mypy_cache', '.tox',
            'venv', 'env', '.env', 'virtualenv', '.venv', '.virtualenvs',
            'site-packages', 'dist-packages',
            # Build
            'build', 'dist', 'out', 'output', 'target', 'bin', 'obj',
            '_build', '.build', 'cmake-build-debug', 'cmake-build-release',
            # IDE
            '.idea', '.vscode', '.vs', '.eclipse', '.settings',
            # Test coverage
            'coverage', 'htmlcov', '.coverage',
            # Temp
            'tmp', 'temp', '.tmp', '.temp', 'cache', '.cache',
            # Docs build
            '_site', 'site', '.docusaurus', 'docs/_build',
        }
        
    def should_include_file(self, filepath: str, filename: str) -> Tuple[bool, str]:
        """Determine if file should be included. Returns (should_include, category)."""
        # Check if path contains excluded directory
        path_parts = filepath.split(os.sep)
        for part in path_parts:
            if part.lower() in {d.lower() for d in self.exclude_dirs}:
                return False, "excluded"
        
        # Quick exclude checks
        filename_lower = filename.lower()
        
        # Check exclude patterns
        for pattern in self.exclude_patterns:
            if fnmatch.fnmatch(filename_lower, pattern.lower()):
                return False, "excluded"
                
        # Check if source code
        _, ext = os.path.splitext(filename_lower)
        if ext in self.source_code_extensions:
            # Additional filtering for test files
            if any(test_pattern in filename_lower for test_pattern in 
                   ['test_', '_test.', '.test.', '.spec.', '_spec.']):
                return True, "test"  # Mark as test but include
            return True, "source"
            
        # Check if important config (be selective)
        if filename in ['requirements.txt', 'package.json', 'Dockerfile', 
                       'docker-compose.yml', 'Makefile', 'setup.py', 'pyproject.toml']:
            return True, "config"
            
        # Main documentation only
        if filename_lower in ['readme.md', 'readme.rst', 'readme.txt']:
            return True, "doc"
            
        # Check if it's a dotfile config in root
        if filename.startswith('.') and '/' not in filepath:
            if filename in ['.gitignore', '.dockerignore', '.editorconfig']:
                return True, "config"
                
        return False, "excluded"
        
    def is_excluded_dir(self, dirname: str) -> bool:
        """Check if directory should be excluded."""
        return dirname.lower() in {d.lower() for d in self.exclude_dirs} or dirname.startswith('.')

def detect_languages(folder_path: str) -> Dict[str, int]:
    """Detect programming languages in the folder."""
    language_files = defaultdict(int)
    classifier = FileClassifier()
    
    lang_extensions = {
        'Python': {'.py', '.pyw'},
        'JavaScript': {'.js', '.mjs', '.cjs'},
        'TypeScript': {'.ts', '.tsx'},
        'Java': {'.java'},
        'C++': {'.cpp', '.hpp', '.cc', '.cxx', '.h'},
        'C': {'.c', '.h'},
        'C#': {'.cs'},
        'Go': {'.go'},
        'Rust': {'.rs'},
        'Ruby': {'.rb'},
        'PHP': {'.php'},
        'Swift': {'.swift'},
        'Kotlin': {'.kt', '.kts'},
    }
    
    for root, dirs, files in os.walk(folder_path):
        dirs[:] = [d for d in dirs if not classifier.is_excluded_dir(d)]
        
        for file in files:
            filepath = os.path.join(root, file)
            should_include, _ = classifier.should_include_file(filepath, file)
            if should_include:
                _, ext = os.path.splitext(file.lower())
                for lang, extensions in lang_extensions.items():
                    if ext in extensions:
                        language_files[lang] += 1
                        break
                        
    return dict(sorted(language_files.items(), key=lambda x: x[1], reverse=True))

def calculate_code_metrics(lines: List[str]) -> Dict[str, int]:
    """Calculate basic code metrics efficiently."""
    metrics = {
        'functions': 0,
        'classes': 0,
        'imports': 0,
    }
    
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
            
        # Quick pattern matching
        if re.match(r'^(def|function|func)\s+', stripped):
            metrics['functions'] += 1
        elif re.match(r'^class\s+', stripped):
            metrics['classes'] += 1
        elif re.match(r'^(import|from|require|include|use|using)\s+', stripped):
            metrics['imports'] += 1
            
    return metrics

def compress_file_content(filepath: str, content: str, level: int) -> Tuple[str, Dict[str, int]]:
    """Compress file content based on compression level."""
    if level == 0:
        return content, {'original_lines': len(content.splitlines())}
        
    lines = content.splitlines()
    original_lines = len(lines)
    stats = defaultdict(int)
    stats['original_lines'] = original_lines
    result = []
    
    # Level 1: Remove extra empty lines and trailing whitespace
    if level >= 1:
        consecutive_empty = 0
        for line in lines:
            line = line.rstrip()  # Remove trailing whitespace
            if line:
                result.append(line)
                consecutive_empty = 0
            else:
                if consecutive_empty == 0:
                    result.append('')  # Keep one empty line
                else:
                    stats['empty_lines_removed'] += 1
                consecutive_empty += 1
                
        lines = result
        result = []
        
    # Level 2: Remove comments and compress functions
    if level >= 2:
        i = 0
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            
            # Remove standalone comments (but keep inline important ones)
            if stripped.startswith(('#', '//', '/*')) and not any(
                kw in stripped.upper() for kw in ['TODO', 'FIXME', 'HACK', 'BUG', 'NOTE', 'IMPORTANT']):
                stats['comments_removed'] += 1
                i += 1
                continue
                
            # Remove print/console.log statements
            if re.match(r'^[\s]*(print|console\.(log|debug|info)|println|printf|puts)\s*\(', line):
                stats['debug_statements_removed'] += 1
                i += 1
                continue
                
            # Compress function bodies
            if re.match(r'^[\s]*(def|function|func|fn|sub|method)\s+\w+', line):
                result.append(line)
                indent = len(line) - len(line.lstrip())
                j = i + 1
                body_lines = 0
                
                # Count function body lines
                while j < len(lines):
                    next_line = lines[j]
                    if next_line.strip() and len(next_line) - len(next_line.lstrip()) <= indent:
                        break
                    body_lines += 1
                    j += 1
                    
                if body_lines > 10:  # Only compress larger functions
                    result.append(f"{' ' * (indent + 4)}# ... {body_lines} lines ...")
                    stats['function_lines_compressed'] += body_lines - 1
                    i = j
                    continue
                else:
                    # Keep small functions intact
                    for k in range(i + 1, j):
                        result.append(lines[k])
                    i = j
                    continue
                    
            result.append(line)
            i += 1
            
        lines = result
        result = []
        
    # Level 3: Remove docstrings and test functions
    if level >= 3:
        i = 0
        in_docstring = False
        docstring_char = None
        
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            
            # Skip entire test functions
            if re.match(r'^[\s]*(def|function|func)\s*(test_|_test|test[A-Z])', line):
                indent = len(line) - len(line.lstrip())
                j = i + 1
                while j < len(lines) and (not lines[j].strip() or 
                      len(lines[j]) - len(lines[j].lstrip()) > indent):
                    j += 1
                stats['test_functions_removed'] += j - i
                i = j
                continue
                
            # Remove docstrings
            if not in_docstring and stripped.startswith(('"""', "'''")):
                docstring_char = '"""' if '"""' in stripped else "'''"
                if stripped.count(docstring_char) == 2:  # Single line docstring
                    stats['docstrings_removed'] += 1
                    i += 1
                    continue
                in_docstring = True
                
            if in_docstring:
                if docstring_char in line:
                    in_docstring = False
                stats['docstrings_removed'] += 1
                i += 1
                continue
                
            # Remove type hints from function signatures
            if 'def ' in line and '->' in line:
                line = re.sub(r'\s*->\s*[^:]+:', ':', line)
                stats['type_hints_removed'] += 1
                
            result.append(line)
            i += 1
            
        lines = result
        
    # Level 4: Maximum compression
    if level >= 4:
        result = []
        for line in lines:
            # Remove ALL comments
            if '#' in line:
                code_part = line.split('#')[0].rstrip()
                if code_part:
                    result.append(code_part)
                    stats['all_comments_removed'] += 1
                continue
            elif '//' in line:
                code_part = line.split('//')[0].rstrip()
                if code_part:
                    result.append(code_part)
                    stats['all_comments_removed'] += 1
                continue
                
            # Minify whitespace around operators
            line = re.sub(r'\s*([=+\-*/])\s*', r'\1', line)
            
            result.append(line)
            
        lines = result
        
    stats['final_lines'] = len(lines)
    stats['lines_removed'] = original_lines - len(lines)
    stats['compression_ratio'] = (1 - len(lines) / original_lines) * 100 if original_lines > 0 else 0
    
    return '\n'.join(lines), dict(stats)

def process_repository(folder_path: str, args) -> Tuple[List[Tuple[str, str]], Dict[str, Any]]:
    """Process repository and return files with stats."""
    classifier = FileClassifier()
    stats = {
        'total_files': 0,
        'total_size': 0,
        'total_lines': 0,
        'original_size': 0,
        'compressed_size': 0,
        'languages': defaultdict(int),
        'categories': defaultdict(int),
        'compression': defaultdict(int),
        'file_metrics': defaultdict(int),
    }
    
    # Collect files
    files_to_process = []
    
    for root, dirs, files in os.walk(folder_path):
        # Filter directories
        dirs[:] = [d for d in dirs if not classifier.is_excluded_dir(d)]
        
        for file in files:
            filepath = os.path.join(root, file)
            
            # Skip large files
            try:
                file_size = os.path.getsize(filepath)
                if file_size > args.max_file_size:
                    continue
                stats['original_size'] += file_size
            except:
                continue
                
            should_include, category = classifier.should_include_file(filepath, file)
            
            if should_include:
                files_to_process.append((filepath, category))
                stats['categories'][category] += 1
                
    # Process files
    processed_files = []
    
    # Progress bar
    if TQDM_AVAILABLE and not args.quiet:
        pbar = tqdm.tqdm(total=len(files_to_process), desc="Processing")
    else:
        pbar = None
        
    for filepath, category in files_to_process:
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
            # Skip empty files
            if not content.strip():
                continue
                
            # Track stats
            stats['total_files'] += 1
            original_lines = len(content.splitlines())
            stats['total_lines'] += original_lines
            
            # Detect language
            _, ext = os.path.splitext(filepath)
            ext_lower = ext.lower()
            if ext_lower in ['.py', '.pyw']:
                stats['languages']['Python'] += 1
            elif ext_lower in ['.js', '.jsx', '.mjs']:
                stats['languages']['JavaScript'] += 1
            elif ext_lower in ['.ts', '.tsx']:
                stats['languages']['TypeScript'] += 1
            elif ext_lower in ['.java']:
                stats['languages']['Java'] += 1
            elif ext_lower in ['.go']:
                stats['languages']['Go'] += 1
            elif ext_lower in ['.rs']:
                stats['languages']['Rust'] += 1
            elif ext_lower in ['.cpp', '.cc', '.cxx', '.hpp', '.h']:
                stats['languages']['C/C++'] += 1
            elif ext_lower in ['.cs']:
                stats['languages']['C#'] += 1
            elif ext_lower in ['.rb']:
                stats['languages']['Ruby'] += 1
            elif ext_lower in ['.php']:
                stats['languages']['PHP'] += 1
                
            # Apply compression
            if args.compress > 0 and category == "source":
                compressed_content, comp_stats = compress_file_content(
                    filepath, content, args.compress
                )
                content = compressed_content
                
                # Track compression stats
                for key, value in comp_stats.items():
                    stats['compression'][key] += value
                    
            stats['compressed_size'] += len(content)
            processed_files.append((filepath, content))
            
        except Exception as e:
            if args.verbose:
                print(f"Error processing {filepath}: {e}")
                
        if pbar:
            pbar.update(1)
            
    if pbar:
        pbar.close()
        
    return processed_files, stats

def format_output(processed_files: List[Tuple[str, str]], stats: Dict[str, Any], 
                 args, folder_path: str) -> str:
    """Format the output efficiently for LLM consumption."""
    output = []
    
    # Minimal header
    project_name = os.path.basename(folder_path)
    
    if args.format == 'markdown':
        output.append(f"# {project_name}")
        output.append(f"Files: {stats['total_files']} | Lines: {stats['total_lines']:,}")
        if args.compress > 0:
            output.append(f"Compression: Level {args.compress}")
        output.append("")
    else:
        output.append(f"Repository: {project_name}")
        output.append(f"Files: {stats['total_files']} | Lines: {stats['total_lines']:,}")
        if args.compress > 0:
            output.append(f"Compression: Level {args.compress}")
        output.append("-" * 40)
        
    # Process files
    for filepath, content in processed_files:
        rel_path = os.path.relpath(filepath, folder_path)
        
        if args.format == 'markdown':
            _, ext = os.path.splitext(filepath)
            lang = {
                '.py': 'python', '.js': 'javascript', '.ts': 'typescript',
                '.java': 'java', '.go': 'go', '.rs': 'rust', '.rb': 'ruby',
                '.cpp': 'cpp', '.c': 'c', '.cs': 'csharp', '.php': 'php',
                '.swift': 'swift', '.kt': 'kotlin', '.scala': 'scala',
                '.jsx': 'jsx', '.tsx': 'tsx', '.sh': 'bash',
                '.sql': 'sql', '.r': 'r', '.R': 'r',
            }.get(ext.lower(), '')
            
            output.append(f"\n## {rel_path}")
            output.append(f"```{lang}")
            output.append(content)
            output.append("```")
        else:
            output.append(f"\n{'='*60}")
            output.append(f"FILE: {rel_path}")
            output.append(f"{'='*60}")
            output.append(content)
            
    return '\n'.join(output)

def print_analysis(stats: Dict[str, Any], compression_ratio: float, output_size: int, 
                  output_tokens: int, args):
    """Print analysis to console only."""
    print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
    print(f"{Colors.BOLD}📊 Repository Analysis Summary{Colors.ENDC}")
    print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
    
    # File breakdown
    print(f"\n{Colors.GREEN}📁 Files Processed:{Colors.ENDC}")
    total_excluded = stats.get('excluded_files', 0)
    for category, count in sorted(stats['categories'].items()):
        print(f"  {category.title()}: {count}")
    if total_excluded > 0:
        print(f"  {Colors.DIM}Excluded: {total_excluded}{Colors.ENDC}")
        
    # Language breakdown
    if stats['languages']:
        print(f"\n{Colors.GREEN}💻 Languages Detected:{Colors.ENDC}")
        for lang, count in sorted(stats['languages'].items(), 
                                 key=lambda x: x[1], reverse=True)[:5]:
            percentage = (count / stats['total_files'] * 100) if stats['total_files'] > 0 else 0
            print(f"  {lang}: {count} files ({percentage:.1f}%)")
            
    # Size analysis
    print(f"\n{Colors.GREEN}📏 Size Analysis:{Colors.ENDC}")
    print(f"  Original: {format_bytes(stats['original_size'])} ({stats['total_lines']:,} lines)")
    print(f"  Output: {format_bytes(output_size)} ({output_tokens:,} tokens)")
    
    if compression_ratio > 0:
        print(f"  {Colors.BOLD}Reduction: {compression_ratio:.1f}%{Colors.ENDC}")
        
    # Compression details
    if args.compress > 0 and stats['compression']:
        print(f"\n{Colors.GREEN}🗜️  Compression Details (Level {args.compress}):{Colors.ENDC}")
        print(f"\n{CompressionLevel.get_description(args.compress)}")
        
        if any(key in stats['compression'] for key in ['empty_lines_removed', 'comments_removed', 
                                                       'function_lines_compressed', 'test_functions_removed']):
            print(f"\n{Colors.CYAN}Compression Statistics:{Colors.ENDC}")
            
            comp_stats = stats['compression']
            if 'empty_lines_removed' in comp_stats:
                print(f"  Empty lines removed: {comp_stats['empty_lines_removed']:,}")
            if 'comments_removed' in comp_stats:
                print(f"  Comments removed: {comp_stats['comments_removed']:,}")
            if 'debug_statements_removed' in comp_stats:
                print(f"  Debug statements removed: {comp_stats['debug_statements_removed']:,}")
            if 'function_lines_compressed' in comp_stats:
                print(f"  Function lines compressed: {comp_stats['function_lines_compressed']:,}")
            if 'test_functions_removed' in comp_stats:
                print(f"  Test functions removed: {comp_stats['test_functions_removed']:,}")
            if 'docstrings_removed' in comp_stats:
                print(f"  Docstrings removed: {comp_stats['docstrings_removed']:,}")
            if 'type_hints_removed' in comp_stats:
                print(f"  Type hints removed: {comp_stats['type_hints_removed']:,}")
            if 'all_comments_removed' in comp_stats:
                print(f"  All comments removed: {comp_stats['all_comments_removed']:,}")
            if 'lines_removed' in comp_stats:
                print(f"  {Colors.BOLD}Total lines removed: {comp_stats['lines_removed']:,}{Colors.ENDC}")
        
    # Token analysis with context windows
    print(f"\n{Colors.GREEN}🎯 Token Analysis:{Colors.ENDC}")
    print(f"  Estimated tokens: {Colors.BOLD}{format_number(output_tokens)}{Colors.ENDC}")
    
    if output_tokens < 32000:
        print(f"  ✓ Fits in Phi-4 (32K)")
    elif output_tokens < 64000:
        print(f"  ✓ Fits in Llama 4 Maverick (64K)")
    elif output_tokens < 128000:
        print(f"  ✓ Fits in GPT-4o (128K)")
    elif output_tokens < 200000:
        print(f"  ✓ Fits in Claude 4 (200K)")
    elif output_tokens < 1000000:
        print(f"  ✓ Fits in GPT-4.1 (1M)")
    else:
        print(f"  ⚠️  Exceeds common model limits")
        
    # Token estimation method
    if TIKTOKEN_AVAILABLE:
        print(f"  {Colors.DIM}(Using tiktoken cl100k_base encoding){Colors.ENDC}")
    else:
        print(f"  {Colors.DIM}(Using heuristic estimation){Colors.ENDC}")

# Unit Tests
class TestLLMCodeAnalyzer(unittest.TestCase):
    """Unit tests for the LLM code analyzer."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.classifier = FileClassifier()
        
    def test_file_classifier_source_code(self):
        """Test source code file detection."""
        test_cases = [
            ('main.py', True, 'source'),
            ('app.js', True, 'source'),
            ('test_utils.py', True, 'test'),
            ('component.tsx', True, 'source'),
            ('README.md', True, 'doc'),
            ('package.json', True, 'config'),
            ('package-lock.json', False, 'excluded'),
            ('node_modules/lib.js', False, 'excluded'),
            ('image.png', False, 'excluded'),
            ('data.db', False, 'excluded'),
            ('yarn.lock', False, 'excluded'),
            ('Pipfile.lock', False, 'excluded'),
        ]
        
        for filename, should_include, expected_category in test_cases:
            with self.subTest(filename=filename):
                result, category = self.classifier.should_include_file(filename, 
                                                                      os.path.basename(filename))
                self.assertEqual(result, should_include, 
                               f"{filename} should_include={should_include}")
                if should_include:
                    self.assertEqual(category, expected_category,
                                   f"{filename} category={expected_category}")
                    
    def test_excluded_directories(self):
        """Test directory exclusion."""
        excluded = ['node_modules', '.git', '__pycache__', 'venv', 'build', 'dist']
        included = ['src', 'lib', 'app', 'components']
        
        for dirname in excluded:
            self.assertTrue(self.classifier.is_excluded_dir(dirname),
                          f"{dirname} should be excluded")
            
        for dirname in included:
            self.assertFalse(self.classifier.is_excluded_dir(dirname),
                           f"{dirname} should not be excluded")
                           
    def test_compression_levels(self):
        """Test different compression levels."""
        # Sample with standalone comment at top
        sample_code = """# Standalone comment at file level
print("Top level debug")

def example_function():
    '''This is a docstring'''
    # This is a comment inside function
    x = 1
    y = 2
    
    
    return x + y

def test_example():
    # Test function
    assert example_function() == 3
    
def another_function():
    '''Another docstring'''
    print("Debug output")
    # TODO: Important note
    result = []
    for i in range(100):
        result.append(i * 2)
    return result
    
def large_function():
    '''This function has more than 10 lines in body'''
    a = 1
    b = 2
    c = 3
    d = 4
    e = 5
    f = 6
    g = 7
    h = 8
    i = 9
    j = 10
    k = 11
    l = 12
    return a + b + c + d + e + f + g + h + i + j + k + l
"""
        
        # Level 0: No compression
        result, stats = compress_file_content('test.py', sample_code, 0)
        self.assertEqual(result, sample_code)
        self.assertEqual(stats['original_lines'], len(sample_code.splitlines()))
        
        # Level 1: Remove empty lines
        result, stats = compress_file_content('test.py', sample_code, 1)
        # Count empty lines in result
        result_empty_lines = sum(1 for line in result.splitlines() if not line.strip())
        original_empty_lines = sum(1 for line in sample_code.splitlines() if not line.strip())
        self.assertLess(result_empty_lines, original_empty_lines)
        self.assertGreater(stats.get('empty_lines_removed', 0), 0)
        
        # Level 2: Remove standalone comments and debug, compress large functions
        result, stats = compress_file_content('test.py', sample_code, 2)
        self.assertNotIn('# Standalone comment at file level', result)  # Standalone removed
        self.assertNotIn('print("Top level debug")', result)  # Top level print removed
        self.assertIn('# This is a comment inside function', result)  # Inside function kept
        self.assertIn('# TODO: Important note', result)  # Keep TODO
        self.assertIn('print("Debug output")', result)  # Inside small function, kept
        self.assertIn('# ... 14 lines ...', result)  # Large function compressed
        
        # Level 3: Remove docstrings and tests
        result, stats = compress_file_content('test.py', sample_code, 3)
        self.assertNotIn("'''This is a docstring'''", result)
        self.assertNotIn('test_example', result)
        self.assertGreater(stats.get('test_functions_removed', 0), 0)
        
        # Level 4: Maximum compression
        result, stats = compress_file_content('test.py', sample_code, 4)
        self.assertNotIn('# TODO', result)  # Even TODO removed
        self.assertNotIn('# This is a comment inside function', result)  # All comments removed
        
    def test_token_estimation(self):
        """Test token estimation."""
        # Test various text samples
        samples = [
            ("Hello world", 2, 4),  # Simple text
            ("def function():\n    return 42", 5, 15),  # Code
            ("x = 1\ny = 2\nz = x + y", 10, 20),  # More code
        ]
        
        for text, min_tokens, max_tokens in samples:
            tokens = estimate_tokens(text)
            self.assertGreaterEqual(tokens, min_tokens, 
                                  f"Token count for '{text}' too low: {tokens}")
            self.assertLessEqual(tokens, max_tokens,
                               f"Token count for '{text}' too high: {tokens}")
    
    def test_format_bytes(self):
        """Test byte formatting."""
        self.assertEqual(format_bytes(100), "100.0B")
        self.assertEqual(format_bytes(1024), "1.0KB")
        self.assertEqual(format_bytes(1024 * 1024), "1.0MB")
        self.assertEqual(format_bytes(1536 * 1024), "1.5MB")
        
    def test_compression_ratio_calculation(self):
        """Test compression ratio calculation."""
        # Create a file with known compressible content
        test_content = """
# This is a comment
def test_function():
    '''
    This is a long docstring
    that spans multiple lines
    '''
    print("Debug 1")
    print("Debug 2")
    print("Debug 3")
    
    
    
    # Another comment
    return True


def another_test():
    pass
"""
        
        result, stats = compress_file_content('test.py', test_content, 3)
        
        # Verify compression actually happened
        self.assertLess(len(result.splitlines()), len(test_content.splitlines()))
        self.assertGreater(stats['compression_ratio'], 0)
        self.assertLess(stats['final_lines'], stats['original_lines'])

def run_tests():
    """Run unit tests."""
    print(f"\n{Colors.CYAN}Running unit tests...{Colors.ENDC}")
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestLLMCodeAnalyzer)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    if result.wasSuccessful():
        print(f"\n{Colors.GREEN}✓ All tests passed!{Colors.ENDC}")
    else:
        print(f"\n{Colors.FAIL}✗ Some tests failed{Colors.ENDC}")
        
    return result.wasSuccessful()

def main():
    parser = argparse.ArgumentParser(
        description='LLM Code Repository Analyzer - Optimized for minimal token usage',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Compression Levels:
  0 - No compression (original code as-is)
  1 - Light: Remove extra whitespace
  2 - Moderate: Remove comments, compress large functions  
  3 - Aggressive: Remove docs, tests, type hints
  4 - Maximum: Extreme minification

Token estimates use tiktoken (GPT-4) when available, or heuristics otherwise.

Examples:
  %(prog)s /path/to/repo
  %(prog)s . --compress 2 --format markdown
  %(prog)s /project --output analysis --compress 3
  %(prog)s --run-tests
        """)
    
    parser.add_argument('folder_path', nargs='?', default='.', 
                       help='Path to analyze (default: current directory)')
    parser.add_argument('-c', '--compress', type=int, default=0, 
                       choices=[0, 1, 2, 3, 4],
                       help='Compression level (default: 0)')
    parser.add_argument('-f', '--format', choices=['text', 'markdown'], 
                       default='text', help='Output format (default: text)')
    parser.add_argument('-o', '--output', type=str, 
                       help='Output filename (without extension)')
    parser.add_argument('--max-file-size', type=int, default=500*1024, 
                       help='Max file size in bytes (default: 500KB)')
    parser.add_argument('-q', '--quiet', action='store_true', 
                       help='Minimal output')
    parser.add_argument('-v', '--verbose', action='store_true', 
                       help='Verbose output')
    parser.add_argument('--run-tests', action='store_true', 
                       help='Run unit tests')
    
    args = parser.parse_args()
    
    # Run tests if requested
    if args.run_tests:
        success = run_tests()
        sys.exit(0 if success else 1)
        
    # Validate input
    if not os.path.isdir(args.folder_path):
        print(f"{Colors.FAIL}Error: {args.folder_path} is not a directory{Colors.ENDC}")
        sys.exit(1)
        
    folder_path = os.path.abspath(args.folder_path)
    
    if not args.quiet:
        print(f"\n{Colors.BOLD}🚀 LLM Code Repository Analyzer{Colors.ENDC}")
        print(f"📁 Repository: {folder_path}")
        print(f"🗜️  Compression: Level {args.compress}")
        
    # Process repository
    start_time = time.time()
    processed_files, stats = process_repository(folder_path, args)
    
    if not processed_files:
        print(f"{Colors.FAIL}No relevant files found{Colors.ENDC}")
        sys.exit(1)
        
    # Format output
    output_content = format_output(processed_files, stats, args, folder_path)
    
    # Calculate tokens
    output_tokens = estimate_tokens(output_content)
    
    # Generate filename
    if args.output:
        output_file = args.output
    else:
        project_name = os.path.basename(folder_path)
        # Static name based on project - will overwrite on repeated runs
        output_file = f"llm_repo_{project_name}"
        
    # Add extension
    if args.format == 'markdown':
        output_file += '.md'
    else:
        output_file += '.txt'
        
    # Write file (optionally compressed)
    if args.compress >= 3:
        output_file += '.gz'
        with gzip.open(output_file, 'wt', encoding='utf-8') as f:
            f.write(output_content)
    else:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(output_content)
            
    # Calculate final stats
    output_size = os.path.getsize(output_file)
    compression_ratio = (1 - (output_size / stats['original_size']) * 100) if stats['original_size'] > 0 else 0
    
    # Print analysis (console only, not in file)
    if not args.quiet:
        print_analysis(stats, compression_ratio, output_size, output_tokens, args)
        print(f"\n{Colors.GREEN}✓ Output saved to: {output_file}{Colors.ENDC}")
        print(f"⏱️  Processing time: {time.time() - start_time:.1f}s")

if __name__ == '__main__':
    main()