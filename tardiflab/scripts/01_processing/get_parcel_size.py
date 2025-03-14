#!/usr/bin/env python3.7
# -*- coding: utf-8 -*-


import sys
import numpy as np

FILE = sys.argv[1]

data = np.loadtxt(FILE)
mean = np.mean(data)
std = np.std(data, ddof=1)
min_val = np.min(data)
max_val = np.max(data)

print(f"Mean: {mean:.2f}, Min: {min_val:.2f}, Max: {max_val:.2f}, Std Dev: {std:.2f}")
