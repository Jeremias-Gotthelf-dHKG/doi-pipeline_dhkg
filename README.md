# doi-pipeline_dhkg

The dHKG uses DOI as an identification and reference mechanism for edited materials and long-form commentary.

Generally, new DOIs are assigned once a year in the course of the yearly release.

## Creating and updating DOIs 

This repository contains a pipeline script (`pipeline.xpl`) that facilitates the creation and curation of DOI identifiers.

It takes a ZIP archive of TEI files ("input-data.zip") and assigns a DOI to each of them. A number of auxiliary files are generated that e.g. assist the integration of the DOIs into the eXist database of the project.

## How to use

Run `pipeline.xpl` (using an XProc 3 processor such as xmlcalabash3 or MorganaXProc-III).

It is required to supply credentials when invoking the pipeline. The arguments are `user`, and `pw`.

Add the command argument `mode=prod` for a production run.

The pipeline creates three executable scripts in the directory `output`. These contain sensitive data and are not part of this repository.

Change to that directory and exceute the appropriate script.

### Requirements

* Install an XProc processor
  * [xmlcalabash3](https://codeberg.org/xmlcalabash/xmlcalabash3/releases) 
  * [MorganaXProc-IIIse](https://www.xml-project.com/morganaxproc-iiise.html)
* If necesssary, also install [Saxon HE](https://github.com/Saxonica/Saxon-HE/releases) (usually comes bundled)

* Credentials for DataCite test repository (`unibe.dhkg-test`) and production repository (`unibe.dhkg`)

# To consider

Make sure the correct DOI prefix and URLs are set before running any script (DataCite test vs production environments).

Currently, the relative path to the ZIP file needs to be specified directly in the pipeline file (reason: @href cannot be set dynamically). We might change this using `p:load` or similar at a later point.
