import random
import sys
import pathlib

WIDTH = 16

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 64
    random.seed(42)
    script_dir = pathlib.Path(__file__).resolve().parent
    out_path = script_dir.parent / "sim" / "input_data.txt"
    with open(out_path, "w") as f:
        for _ in range(n):
            d = random.randint(0, (1 << WIDTH) - 1)
            f.write(f"{d:04x}\n")
    print(f"Wrote {n} words to {out_path}")

if __name__ == "__main__":
    main()