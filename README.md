# GID-PUF: MATLAB Scripts and Experimental Data

This repository contains MATLAB scripts, SRAM measurement data, and saved processing results accompanying a master's thesis on GID-PUF. The scripts cover response extraction, filtering, collision search, and probability calculations.

The files were developed and run as individual scripts during the experimental work. Input files, device groups, parameters, and output folders are selected manually.

## Repository contents

| Folder | Contents |
| --- | --- |
| `MATLAB Data Processing/` | Extraction of 8-bit or non-overlapping 16-bit responses; Hamming-distance and Hamming-weight filtering; search for responses shared by all selected devices. |
| `MATLAB Probability Calculations/` | Functions and parameter-sweep scripts for the probability model and its inverse problem. |
| `Data Processing Results/` | Raw measurement exports, an SQLite database, extracted responses, filtered address-value pairs, and collision reports. |

## Requirements

- MATLAB R2024a or later for running the filtering scripts in their current form. These scripts contain local functions interspersed with script statements; earlier MATLAB releases require local functions to be placed at the end of the file.
- Statistics and Machine Learning Toolbox for the probability calculations, which use `normcdf` and `norminv`.
- MATLAB's graphical interface for the file and folder selection dialogs used by several processing scripts.

## Experimental data and saved results

Raw data are stored in `Data Processing Results/Raw PUF extract/`:

| File | Description |
| --- | --- |
| `puf_measurements_202605141543_48000.csv` | Measurement export with 48,000-byte SRAM dumps. |
| `puf_measurements_202605281702_96000.csv` | Measurement export with 96,000-byte SRAM dumps. |
| `puf_data.db` | SQLite measurement database. The MATLAB extraction scripts read the CSV exports directly. |

The CSV columns are `id`, `device_id`, `dump_index`, `timestamp`, `puf_data_hex`, `puf_addr`, `puf_len`, and `session_timestamp`. `puf_data_hex` contains the hexadecimal dump; `puf_addr` is its starting byte address, and `puf_len` is its length in bytes.

Saved processing results are grouped by response width and dump length:

| Location under `Data Processing Results/` | Devices in saved collision report | Distinct shared responses in saved report |
| --- | --- | --- |
| `Processing results 8-bit/48000/` | 5 | 70 |
| `Processing results 16-bit (NO overlap)/48000/` | 5 | 22 |
| `Processing results 16-bit (NO overlap)/96000/` | 6 | 205 |

These counts are recorded in the included `collisions.txt` files. The folders preserve different processing runs and device groups; select the appropriate group when comparing results. The extracted dumps shown in these result folders contain ten measurements per included device.

Each result group includes extracted dumps, reports after intra-device Hamming-distance and Hamming-weight filtering, reports after inter-device filtering, and a collision report. Folder names in the archive were organised manually and can differ from the scripts' default output folder names.

## Data-processing scripts

The scripts are in `MATLAB Data Processing/`.

| Script | Purpose |
| --- | --- |
| `Exp_data_8_processing.m` | Reads the CSV specified by `filename` and exports individual bytes with their SRAM addresses, separately for each device and dump. |
| `Exp_data_16_processing_NONoverlap.m` | Opens a CSV selection dialog and exports non-overlapping 16-bit responses formed from successive byte pairs. Addresses advance by two bytes. |
| `Exp_data_filtering_HDintra_HW.m` | Selects addresses present in every dump, filters by mean normalised intra-device Hamming distance, and then filters the modal response by normalised Hamming weight. |
| `Exp_data_filtering_HDinter.m` | Applies inter-device filtering to the per-device address-value files produced by the previous stage. |
| `Collision_search.m` | Finds distinct response values present in every selected device file and records one address per device for each shared value. |

### Running the processing stages

Use a separate working folder for each combination of dataset, response width, and device group. Run each script as a whole file.

1. **Extract responses.** Run `Exp_data_8_processing.m` or `Exp_data_16_processing_NONoverlap.m`. For the 8-bit script, first edit `filename` to point to the desired CSV; its default is the 48,000-byte export. The 16-bit script requests the CSV interactively. Output is written below the MATLAB current folder as `extracted_puf_data_all/` or `extracted_puf_data_all_16bit_no_overlap/`, with one subfolder per device.

2. **Filter by intra-device Hamming distance and Hamming weight.** Run `Exp_data_filtering_HDintra_HW.m` and select the extracted-data root containing the device subfolders. The default limits are `HDintra <= 0.1` and normalised Hamming weight in `[0.4, 0.6]`. The script detects the response width from the input values. It creates `puf_analysis_results/` inside the selected root and writes one report per device.

3. **Prepare filenames and apply inter-device filtering.** The preceding script currently writes `<device>_puf_analysis_HDintra_HW.txt`, while `Exp_data_filtering_HDinter.m` searches for `<device>_puf_analysis.txt`. Copy the reports into a separate input folder, keeping the intended device group, and rename the copies to `<device>_puf_analysis.txt`. Run `Exp_data_filtering_HDinter.m`, select this folder, and enter the desired range; the default is `[0.4, 0.6]`. Results are written to its `puf_hdinter_filtered/` subfolder.

4. **Search for common responses.** Run `Collision_search.m` and select a folder containing only the intended per-device filtered `.txt` reports. The script writes `collisions.txt` in that folder. Before rerunning, move any existing `collisions.txt` out of the input folder, since the script reads every `.txt` file there as a device input.

To inspect the saved outputs, start directly with the existing filtering reports and `collisions.txt` files. Reprocessing the raw CSVs is not required for reading those results.

### Processing conventions

- Intra-device Hamming distance is averaged over **all pairs of dumps** at each address, then normalised by the response width. The retained response value is the mode of the complete observed values.
- The 16-bit extractor joins successive hexadecimal byte strings in their stored order: bytes `AB` and `CD` produce `ABCD`, associated with the first byte's address. The pairs do not overlap.
- Inter-device filtering compares responses at the same address across the devices on which that address survived the preceding filters. If the mean pairwise distance is within the chosen range, the address is retained on all those devices. Otherwise, it is retained on one device selected using an address-based deterministic seed. An address present on only one device is retained.
- Collision search compares response **values**, which may occur at different addresses on different devices. It reports each distinct shared value once and retains the first listed address for that value on each device; it does not enumerate every possible address combination.
- Processing reports use comment headers beginning with `#` and tab-separated data columns: index, hexadecimal address, and hexadecimal response value.

## Probability calculations

The files in `MATLAB Probability Calculations/` form a separate numerical workflow and do not read the experimental datasets automatically.

| File | Purpose |
| --- | --- |
| `P_K_cdf.m` | Approximates `P(X >= K)` using the model's mean and variance and a normal approximation with continuity correction. |
| `inv_P_K_cdf.m` | Calculates an approximate integer threshold `K` for a target probability. The returned value is restricted to `[1, Q]`. |
| `CDFgrafik_qMxK_VG_matrix_full.m` | Evaluates probabilities over a grid of `M` and `K`, with `N` fixed, and saves a text table. |
| `CDFgrafik_qNxK_VG_matrix_full.m` | Evaluates probabilities over a grid of `N` and `K`, with `M` fixed, and saves a text table. |
| `invCDFgrafik_KMxN_VG_matrix_full.m` | Evaluates inverse thresholds over a grid of `M` and `N` for a fixed target probability and saves a text table. |

The parameter names in these files are:

| Parameter | Meaning |
| --- | --- |
| `w` | Response width in bits. |
| `L` | Full response alphabet size, set to `2^w` in the sweep scripts. |
| `Q` | Number of response values considered as candidates for shared responses in the model. |
| `M` | Number of response samples per device in the model. |
| `N` | Number of devices. |
| `K` | Target number of distinct shared response values. |
| `P_target` | Target probability for the inverse calculation. |

Set MATLAB's current folder to `MATLAB Probability Calculations/`, open a parameter-sweep script, adjust the fixed parameters and ranges at the top, and run it. The helper functions must be on the MATLAB path; using this current folder makes them available. Tables are saved to the current folder. Despite their filenames, the supplied sweep scripts export numerical tables rather than drawing plots.

These routines use a normal approximation. Their outputs, including inverse thresholds, should be interpreted within that approximation and its numerical limits. The parameter values currently stored in the scripts are individual calculation settings, not an automatic selection of all thesis cases.

## Acquisition software and provenance

The SRAM acquisition work was carried out collaboratively. Related firmware and serial-capture software are available separately:

- [ESP32 SRAM acquisition firmware](https://github.com/SeanEmanon/esp32-sram-puf)
- [Serial output capture](https://github.com/etogus/capture-esp32-output)

This repository provides the MATLAB calculations, data processing, and saved experimental outputs. Hardware acquisition and protocol execution are separate from these MATLAB workflows.

## License

See [LICENSE](LICENSE) for the repository's MIT license.

NOTE: This README was prepared with AI formatting assistance. The individual scripts were written and ran manually.