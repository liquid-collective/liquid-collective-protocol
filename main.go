package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/tenderly/tenderly-cli/config"
	"github.com/tenderly/tenderly-cli/hardhat"
	"github.com/tenderly/tenderly-cli/providers"
	"github.com/tenderly/tenderly-cli/rest"
	"github.com/tenderly/tenderly-cli/rest/call"
	"github.com/tenderly/tenderly-cli/rest/payloads"
	"gopkg.in/yaml.v2"
)

func init() {
	config.Init()
}

func NewRest() *rest.Rest {
	return rest.NewRest(
		call.NewAuthCalls(),
		call.NewUserCalls(),
		call.NewProjectCalls(),
		call.NewContractCalls(),
		call.NewExportCalls(),
		call.NewNetworkCalls(),
		call.NewActionCalls(),
		call.NewDevNetCalls(),
		call.NewGatewayCalls(),
		call.NewExtensionCalls(),
	)
}

type ContractABI struct {
	Path string `yaml:"path"`
	Name string `yaml:"name"`
	Tag  string `yaml:"tag"`
}

func UploadContract(cl *rest.Rest, abi *ContractABI, projectSlug, networkID string) error {
	fmt.Printf("Upload contract %v\n", abi)

	// read ABI file
	b, err := os.ReadFile(abi.Path)
	if err != nil {
		return err
	}

	// Unmarshal ABI in HardhatContract object
	hardhatContract := new(hardhat.HardhatContract)
	err = json.Unmarshal(b, hardhatContract)
	if err != nil {
		return err
	}

	// Unmarshal Metadata
	var hardhatMeta providers.ContractMetadata
	if hardhatContract.Metadata != "" {
		err = json.Unmarshal([]byte(hardhatContract.Metadata), &hardhatMeta)
		if err != nil {
			return err
		}

		etherscan := make(map[string]interface{})
		etherscan["language"] = hardhatMeta.Language
		settings := make(map[string]interface{})
		optimizer := make(map[string]interface{})
		optimizer["enabled"] = hardhatMeta.Settings.Optimizer.Enabled
		optimizer["runs"] = hardhatMeta.Settings.Optimizer.Runs
		settings["optimizer"] = optimizer
		etherscan["settings"] = settings
		sources := make(map[string]map[string]string)
		for k, source := range hardhatMeta.Sources {
			sources[k] = make(map[string]string)
			sources[k]["content"] = source.Content
		}
		etherscan["sources"] = sources

		b, err := json.MarshalIndent(etherscan, "", "  ")
		if err != nil {
			return err
		}

		dir := filepath.Dir(abi.Path)
		base := filepath.Base(abi.Path)
		etherscanDir := filepath.Join(dir, "etherscan")
		etherscanPath := filepath.Join(etherscanDir, base)

		if _, err := os.Stat(etherscanDir); os.IsNotExist(err) {
			os.MkdirAll(etherscanDir, 0700) // Create your file
		}

		err = os.WriteFile(strings.ReplaceAll(etherscanPath, ".json", ".solcinput.json"), b, fs.ModePerm)
		if err != nil {
			return err
		}
	}

	// Create upload contract request object
	req := &payloads.UploadContractsRequest{
		Config: &payloads.Config{
			OptimizationsUsed:  func(b bool) *bool { return &b }(*hardhatMeta.Settings.Optimizer.Enabled),
			OptimizationsCount: func(i int) *int { return &i }(*hardhatMeta.Settings.Optimizer.Runs),
			EvmVersion:         func(s string) *string { return &s }(*hardhatMeta.Settings.EvmVersion),
		},
		Tag: abi.Tag,
	}

	version := fmt.Sprintf("v%v", strings.Split(hardhatMeta.Compiler.Version, "+")[0])

	// Loop over contract sources found in metadata to populate the list of contract dependencies
	for path, source := range hardhatMeta.Sources {
		contract := providers.Contract{
			Source:     source.Content,
			SourcePath: path,
			Compiler: providers.ContractCompiler{
				Name:    "solc",
				Version: version,
			},
		}

		//
		// When reaching the ultimate contract, attaches the network information and address of deployment
		// TODO: CompilationTarget attribute has been manually added on nmvalera local dep. We should submit a PR to tenderly-cli to add it
		if name, ok := hardhatMeta.Settings.CompilationTarget[path]; ok {
			contract.Name = name
			contract.Networks = make(map[string]providers.ContractNetwork)
			contract.Networks[networkID] = providers.ContractNetwork{
				Address: hardhatContract.Address,
			}
		}

		req.Contracts = append(req.Contracts, contract)
	}

	resp, err := cl.Contract.UploadContracts(*req, projectSlug)
	if err != nil {
		return err
	}

	if resp.Error != nil {
		return resp.Error
	}

	fmt.Printf("-> Contract uploaded: %v\n", resp.Contracts)

	if abi.Name != "" {
		renameReq := payloads.RenameContractRequest{
			DisplayName: abi.Name,
		}
		resp, err := cl.Contract.RenameContract(renameReq, projectSlug, networkID, hardhatContract.Address)
		if err != nil {
			return err
		}

		if resp != nil && resp.Error != nil {
			return resp.Error
		}

		fmt.Printf("-> Contract renamed to: %v\n", abi.Name)
	}

	return nil
}

type Projects struct {
	Projects map[string]*Project `yaml:"projects"`
}

type Project struct {
	Slug      string         `yaml:"slug"`
	Network   string         `yaml:"network"`
	Contracts []*ContractABI `yaml:"contracts"`
}

func main() {
	cl := NewRest()

	principal, err := cl.User.Principal()
	if err != nil {
		panic(err)
	}

	fmt.Printf("Connected as %v\n", principal)

	// read yaml file
	b, err := os.ReadFile("./tenderly.yml")
	if err != nil {
		panic(err)
	}

	projects := new(Projects)
	err = yaml.Unmarshal(b, projects)
	if err != nil {
		panic(err)
	}

	for _, project := range projects.Projects {
		for _, contract := range project.Contracts {
			err := UploadContract(cl, contract, project.Slug, project.Network)
			if err != nil {
				panic(err)
			}
		}
	}
}
