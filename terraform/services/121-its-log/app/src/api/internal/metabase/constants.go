package metabase

const SQL_NAMED_PARAM_SYMBOL = "$"

type MetabaseOpenMode int

const (
	OpenExistingOnly MetabaseOpenMode = iota
	OpenExistingOrCreateNew
	CreateNew
	ReplaceExisting
)

func (f MetabaseOpenMode) String() string {
	var names = [...]string{
		OpenExistingOnly:        "OpenExistingOnly",
		OpenExistingOrCreateNew: "OpenExistingOrCreateNew",
		CreateNew:               "CreateNew",
		ReplaceExisting:         "ReplaceExisting",
	}
	if f > 0 && int(f) < len(names) {
		return names[f]
	} else {
		return "UnknownMetabaseMode"
	}
}

type FilesystemLocation int

const (
	LiveLocation = iota
	ArchiveLocation
	ExportLocation
)

func (f FilesystemLocation) String() string {
	var names = [...]string{
		LiveLocation:    "Live",
		ArchiveLocation: "Archive",
		ExportLocation:  "Export",
	}
	if f > 0 && int(f) < len(names) {
		return names[f]
	} else {
		return "UnknownFilesystemLocation"
	}
}
