// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

// solhint-disable no-global-import
// solhint-disable no-console

import "@std/Test.sol";

import {Template} from "src/Template.sol";

contract TemplateTest is Test {
    Template private template;

    function setUp() public {
        template = new Template();
    }

    function test_hello() public view {
        string memory answer = template.hello();
        assertEq(answer, "hello world");
    }
}
