#!/usr/bin/env python3
"""Volatility 3 command-line entry point for the portable package."""

import sys

import volatility3.cli


if __name__ == "__main__":
    # Keep plugin output readable on Windows hosts using the embedded runtime.
    sys.stderr.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    volatility3.cli.main()
