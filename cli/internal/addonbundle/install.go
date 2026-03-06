package addonbundle

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

var ErrAddonExists = errors.New("addon already exists")

type InstallResult struct {
	AddonPath   string
	FileCount   int
	Overwritten bool
}

func Install(projectRoot string, force bool) (InstallResult, error) {
	cleanRoot := filepath.Clean(projectRoot)
	addonRoot := filepath.Join(cleanRoot, "addons")
	targetPath := filepath.Join(addonRoot, "godot_bridge")

	overwritten := false
	if info, err := os.Stat(targetPath); err == nil {
		if !info.IsDir() {
			return InstallResult{}, fmt.Errorf("target exists and is not a directory: %s", targetPath)
		}
		if !force {
			return InstallResult{}, ErrAddonExists
		}
		if err := os.RemoveAll(targetPath); err != nil {
			return InstallResult{}, fmt.Errorf("remove existing addon directory: %w", err)
		}
		overwritten = true
	} else if !os.IsNotExist(err) {
		return InstallResult{}, fmt.Errorf("check addon directory: %w", err)
	}

	if err := os.MkdirAll(addonRoot, 0o755); err != nil {
		return InstallResult{}, fmt.Errorf("create addon root: %w", err)
	}

	if err := extractZip(addonRoot, bridgeZip); err != nil {
		return InstallResult{}, err
	}

	fileCount, err := countFiles(targetPath)
	if err != nil {
		return InstallResult{}, fmt.Errorf("count installed addon files: %w", err)
	}

	return InstallResult{
		AddonPath:   targetPath,
		FileCount:   fileCount,
		Overwritten: overwritten,
	}, nil
}

func extractZip(destinationRoot string, zipData []byte) error {
	reader, err := zip.NewReader(bytes.NewReader(zipData), int64(len(zipData)))
	if err != nil {
		return fmt.Errorf("read embedded addon archive: %w", err)
	}

	cleanDestinationRoot := filepath.Clean(destinationRoot)
	prefix := cleanDestinationRoot + string(os.PathSeparator)

	for _, entry := range reader.File {
		rel := filepath.FromSlash(entry.Name)
		cleanRel := filepath.Clean(rel)
		if cleanRel == "." || cleanRel == "" {
			continue
		}

		outPath := filepath.Join(cleanDestinationRoot, cleanRel)
		cleanOutPath := filepath.Clean(outPath)
		if cleanOutPath != cleanDestinationRoot && !strings.HasPrefix(cleanOutPath, prefix) {
			return fmt.Errorf("archive entry escapes destination: %s", entry.Name)
		}

		if entry.FileInfo().IsDir() {
			if err := os.MkdirAll(cleanOutPath, 0o755); err != nil {
				return fmt.Errorf("create directory %s: %w", cleanOutPath, err)
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(cleanOutPath), 0o755); err != nil {
			return fmt.Errorf("create parent directory for %s: %w", cleanOutPath, err)
		}

		if err := writeArchiveFile(cleanOutPath, entry); err != nil {
			return err
		}
	}

	return nil
}

func writeArchiveFile(outPath string, entry *zip.File) error {
	src, err := entry.Open()
	if err != nil {
		return fmt.Errorf("open archive entry %s: %w", entry.Name, err)
	}
	defer func() { _ = src.Close() }()

	dst, err := os.OpenFile(outPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, fileMode(entry))
	if err != nil {
		return fmt.Errorf("create file %s: %w", outPath, err)
	}
	defer func() { _ = dst.Close() }()

	if _, err := io.Copy(dst, src); err != nil {
		return fmt.Errorf("write file %s: %w", outPath, err)
	}

	return nil
}

func fileMode(entry *zip.File) os.FileMode {
	mode := entry.Mode()
	if mode == 0 {
		return 0o644
	}
	return mode
}

func countFiles(rootPath string) (int, error) {
	count := 0
	err := filepath.WalkDir(rootPath, func(_ string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		count++
		return nil
	})
	if err != nil {
		return 0, err
	}

	return count, nil
}
