// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";
import "fhevm/gateway/GatewayCaller.sol";

/// @title WineRegistry with Confidential Data and Search by Name
contract WineRegistry is SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller {
    uint64 public desencryptedIsOrganicValue;

    struct Wine {
        string name;
        string winerie;
        euint128 copper;
        euint128 lead;
        euint128 cadmium;
        euint128 arsenic;
        euint128 cinc;
        euint128 volatileAcidity;
        ebool isOrganic; // Indicates if the wine is organic
        string publicData; // Public metadata associated with the wine
    }

    mapping(string => Wine) private winesByName; // Mapping to search wines by name

    event WineAdded(string name, string winerie, ebool isOrganic, string publicData);

    constructor() {
        Gateway.setGateway(Gateway.gatewayContractAddress());
    }

    function requestDecryption(string memory name) public {
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(winesByName[name].isOrganic);
        Gateway.requestDecryption(cts, this.callbackCounter.selector, 0, block.timestamp + 100, false);
    }

    function callbackCounter(uint256, uint64 decryptedInput) public onlyGateway returns (uint64) {
        desencryptedIsOrganicValue = decryptedInput;
        return decryptedInput;
    }

    function getDecryptedIsOrganic() public view returns (uint64) {
        return desencryptedIsOrganicValue;
    }

    /// @notice Add a wine to the registry
    function addWine(
        string memory name,
        string memory winerie,
        einput copperEncrypted,
        einput leadEncrypted,
        einput cadmiumEncrypted,
        einput arsenicEncrypted,
        einput cincEncrypted,
        einput volatileAcidityEncrypted,
        string memory publicData,
        bytes calldata inputProof
    ) public {
        // Validate and convert encrypted data
        euint128 copper = TFHE.asEuint128(copperEncrypted, inputProof);
        euint128 lead = TFHE.asEuint128(leadEncrypted, inputProof);
        euint128 cadmium = TFHE.asEuint128(cadmiumEncrypted, inputProof);
        euint128 arsenic = TFHE.asEuint128(arsenicEncrypted, inputProof);
        euint128 cinc = TFHE.asEuint128(cincEncrypted, inputProof);
        euint128 volatileAcidity = TFHE.asEuint128(volatileAcidityEncrypted, inputProof);

        // Check if any chemical exceeds 100
        ebool copperExceeds = TFHE.gt(copper, 100);
        ebool leadExceeds = TFHE.gt(lead, 100);
        ebool cadmiumExceeds = TFHE.gt(cadmium, 100);
        ebool arsenicExceeds = TFHE.gt(arsenic, 100);
        ebool cincExceeds = TFHE.gt(cinc, 100);
        ebool volatileAcidityExceeds = TFHE.gt(volatileAcidity, 100);

        // Combine results to determine if the wine is organic
        ebool isOrganic = TFHE.not(
            TFHE.or(
                TFHE.or(
                    TFHE.or(TFHE.or(copperExceeds, leadExceeds), TFHE.or(cadmiumExceeds, arsenicExceeds)),
                    cincExceeds
                ),
                volatileAcidityExceeds
            )
        );

        // Allow encrypted values
        TFHE.allowThis(copper);
        TFHE.allowThis(lead);
        TFHE.allowThis(cadmium);
        TFHE.allowThis(arsenic);
        TFHE.allowThis(cinc);
        TFHE.allowThis(volatileAcidity);
        TFHE.allowThis(isOrganic);

        // Store wine details by name
        winesByName[name] = Wine(
            name,
            winerie,
            copper,
            lead,
            cadmium,
            arsenic,
            cinc,
            volatileAcidity,
            isOrganic,
            publicData
        );

        emit WineAdded(name, winerie, isOrganic, publicData);
    }

    /// @notice Get wine details by name
    function getWine(
        string memory name
    )
        public
        view
        returns (
            string memory winerie,
            euint128 copper,
            euint128 lead,
            euint128 cadmium,
            euint128 arsenic,
            euint128 cinc,
            ebool isOrganic,
            string memory publicData
        )
    {
        Wine storage wine = winesByName[name];
        return (
            wine.winerie,
            wine.copper,
            wine.lead,
            wine.cadmium,
            wine.arsenic,
            wine.cinc,
            wine.isOrganic,
            wine.publicData
        );
    }
}
