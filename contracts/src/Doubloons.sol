// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
                                                                               ,----,
                                               ,--.                          ,/   .`|
,-.----.     ,---,  .--.--.      ,---,       ,--.'|  ,----..               ,`   .'  :   ,---,    ,---,        ,---,.  .--.--.
\    /  \ ,`--.' | /  /    '. ,`--.' |   ,--,:  : | /   /   \            ;    ;     /,`--.' |  .'  .' `\    ,'  .' | /  /    '.
;   :    \|   :  :|  :  /`. / |   :  :,`--.'`|  ' :|   :     :         .'___,/    ,' |   :  :,---.'     \ ,---.'   ||  :  /`. /
|   | .\ ::   |  ';  |  |--`  :   |  '|   :  :  | |.   |  ;. /         |    :     |  :   |  '|   |  .`\  ||   |   .';  |  |--`
.   : |: ||   :  ||  :  ;_    |   :  |:   |   \ | :.   ; /--`          ;    |.';  ;  |   :  |:   : |  '  |:   :  |-,|  :  ;_
|   |  \ :'   '  ; \  \    `. '   '  ;|   : '  '; |;   | ;  __         `----'  |  |  '   '  ;|   ' '  ;  ::   |  ;/| \  \    `.
|   : .  /|   |  |  `----.   \|   |  |'   ' ;.    ;|   : |.' .'            '   :  ;  |   |  |'   | ;  .  ||   :   .'  `----.   \
;   | |  \'   :  ;  __ \  \  |'   :  ;|   | | \   |.   | '_.' :            |   |  '  '   :  ;|   | :  |  '|   |  |-,  __ \  \  |
|   | ;\  \   |  ' /  /`--'  /|   |  ''   : |  ; .''   ; : \  |            '   :  |  |   |  ''   : | /  ; '   :  ;/| /  /`--'  /
:   ' | \.'   :  |'--'.     / '   :  ||   | '`--'  '   | '/  .'            ;   |.'   '   :  ||   | '` ,/  |   |    \'--'.     /
:   : :-' ;   |.'   `--'---'  ;   |.' '   : |      |   :    /              '---'     ;   |.' ;   :  .'    |   :   .'  `--'---'
|   |.'   '---'               '---'   ;   |.'       \   \ .'                         '---'   |   ,.'      |   | ,'
`---'                                 '---'          `---`                                   '---'        `----'

                                                $DBL - Doubloons of the Seven Seas
*/

import "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract Doubloons is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __ERC20_init("Doubloons", "DBL");
        __ERC20Permit_init("Doubloons");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
