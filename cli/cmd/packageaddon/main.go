package main

import (
	"archive/zip"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"sort"
	"time"
)

const (
	sourceRelativePath = "../addons/godot_bridge"
	outputRelativePath = "internal/addonbundle/godot_bridge.zip"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "package addon: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	workingDir, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("resolve working directory: %w", err)
	}

	sourceDir := filepath.Clean(filepath.Join(workingDir, sourceRelativePath))
	outputZip := filepath.Clean(filepath.Join(workingDir, outputRelativePath))

	if err := ensureSourceDir(sourceDir); err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(outputZip), 0o755); err != nil {
		return fmt.Errorf("create output directory: %w", err)
	}

	files, err := collectFiles(sourceDir)
	if err != nil {
		return err
	}

	if err := writeArchive(outputZip, sourceDir, files); err != nil {
		return err
	}

	fmt.Printf("wrote %s (%d files)\n", outputZip, len(files))
	return nil
}

func ensureSourceDir(sourceDir string) error {
	info, err := os.Stat(sourceDir)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("addon source not found: %s", sourceDir)
		}
		return fmt.Errorf("check addon source: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("addon source is not a directory: %s", sourceDir)
	}

	return nil
}

func collectFiles(sourceDir string) ([]string, error) {
	files := make([]string, 0, 128)
	err := filepath.WalkDir(sourceDir, func(filePath string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		rel, err := filepath.Rel(sourceDir, filePath)
		if err != nil {
			return fmt.Errorf("build relative path for %s: %w", filePath, err)
		}
		files = append(files, filepath.ToSlash(rel))
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("walk addon source: %w", err)
	}

	sort.Strings(files)
	return files, nil
}

func writeArchive(outputZip string, sourceDir string, files []string) error {
	tempPath := outputZip + ".tmp"

	tempFile, err := os.Create(tempPath)
	if err != nil {
		return fmt.Errorf("create temp archive: %w", err)
	}

	zipWriter := zip.NewWriter(tempFile)
	for _, relPath := range files {
		if err := writeArchiveFile(zipWriter, sourceDir, relPath); err != nil {
			_ = zipWriter.Close()
			_ = tempFile.Close()
			_ = os.Remove(tempPath)
			return err
		}
	}

	if err := zipWriter.Close(); err != nil {
		_ = tempFile.Close()
		_ = os.Remove(tempPath)
		return fmt.Errorf("finalize archive: %w", err)
	}

	if err := tempFile.Close(); err != nil {
		_ = os.Remove(tempPath)
		return fmt.Errorf("close temp archive: %w", err)
	}

	if err := os.Rename(tempPath, outputZip); err != nil {
		_ = os.Remove(tempPath)
		return fmt.Errorf("replace archive: %w", err)
	}

	return nil
}

func writeArchiveFile(zipWriter *zip.Writer, sourceDir string, relPath string) error {
	sourcePath := filepath.Join(sourceDir, filepath.FromSlash(relPath))
	info, err := os.Stat(sourcePath)
	if err != nil {
		return fmt.Errorf("stat source file %s: %w", sourcePath, err)
	}

	header, err := zip.FileInfoHeader(info)
	if err != nil {
		return fmt.Errorf("create archive header for %s: %w", sourcePath, err)
	}
	header.Name = path.Join("godot_bridge", relPath)
	header.Method = zip.Deflate
	header.Modified = time.Unix(0, 0).UTC()

	archiveWriter, err := zipWriter.CreateHeader(header)
	if err != nil {
		return fmt.Errorf("create archive entry %s: %w", header.Name, err)
	}

	sourceFile, err := os.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("open source file %s: %w", sourcePath, err)
	}
	defer func() { _ = sourceFile.Close() }()

	if _, err := io.Copy(archiveWriter, sourceFile); err != nil {
		return fmt.Errorf("copy source file %s: %w", sourcePath, err)
	}

	return nil
}
