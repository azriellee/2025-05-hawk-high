// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DeployLevelOne} from "../script/DeployLevelOne.s.sol";
import {GraduateToLevelTwo} from "../script/GraduateToLevelTwo.s.sol";
import {LevelOne} from "../src/LevelOne.sol";
import {LevelTwo} from "../src/LevelTwo.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";


contract LevelOneAndGraduateTest is Test {
    DeployLevelOne deployBot;
    GraduateToLevelTwo graduateBot;

    LevelOne levelOneProxy;
    LevelTwo levelTwoImplementation;

    address proxyAddress;
    address levelOneImplementationAddress;
    address levelTwoImplementationAddress;

    MockUSDC usdc;

    address principal;
    uint256 schoolFees;

    // teachers
    address alice;
    address bob;
    // students
    address clara;
    address dan;
    address eli;
    address fin;
    address grey;
    address harriet;

    function setUp() public {
        deployBot = new DeployLevelOne();
        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);

        // graduateBot = new GraduateToLevelTwo();

        usdc = deployBot.getUSDC();
        principal = deployBot.principal();
        schoolFees = deployBot.getSchoolFees();
        levelOneImplementationAddress = deployBot.getImplementationAddress();

        alice = makeAddr("first_teacher");
        bob = makeAddr("second_teacher");

        clara = makeAddr("first_student");
        dan = makeAddr("second_student");
        eli = makeAddr("third_student");
        fin = makeAddr("fourth_student");
        grey = makeAddr("fifth_student");
        harriet = makeAddr("six_student");

        usdc.mint(clara, schoolFees);
        usdc.mint(dan, schoolFees);
        usdc.mint(eli, schoolFees);
        usdc.mint(fin, schoolFees);
        usdc.mint(grey, schoolFees);
        usdc.mint(harriet, schoolFees);
    }

    function test_confirm_first_deployment_is_level_one() public view {
        uint256 expectedTeacherWage = 35;
        uint256 expectedPrincipalWage = 5;
        uint256 expectedPrecision = 100;

        assertEq(levelOneProxy.TEACHER_WAGE(), expectedTeacherWage);
        assertEq(levelOneProxy.PRINCIPAL_WAGE(), expectedPrincipalWage);
        assertEq(levelOneProxy.PRECISION(), expectedPrecision);
        assertEq(levelOneProxy.getPrincipal(), principal);
        assertEq(levelOneProxy.getSchoolFeesCost(), deployBot.schoolFees());
        assertEq(levelOneProxy.getSchoolFeesToken(), address(usdc));
    }

    function test_confirm_add_teacher() public {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();

        assert(levelOneProxy.isTeacher(alice) == true);
        assert(levelOneProxy.isTeacher(bob) == true);
        assert(levelOneProxy.getTotalTeachers() == 2);
    }

    function test_confirm_cannot_add_teacher_if_not_principal() public {
        vm.expectRevert(LevelOne.HH__NotPrincipal.selector);
        levelOneProxy.addTeacher(alice);
    }

    function test_confirm_cannot_add_teacher_twice() public {
        vm.prank(principal);
        levelOneProxy.addTeacher(alice);

        vm.prank(principal);
        vm.expectRevert(LevelOne.HH__TeacherExists.selector);
        levelOneProxy.addTeacher(alice);
    }

    function test_confirm_remove_teacher() public {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();

        vm.prank(principal);
        levelOneProxy.removeTeacher(alice);

        assert(levelOneProxy.isTeacher(alice) == false);
        assert(levelOneProxy.getTotalTeachers() == 1);
    }

    function test_confirm_enroll() public {
        vm.startPrank(clara);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        assert(usdc.balanceOf(address(levelOneProxy)) == schoolFees);
    }

    function test_confirm_cannot_enroll_without_school_fees() public {
        address newStudent = makeAddr("no_school_fees");

        vm.prank(newStudent);
        vm.expectRevert();
        levelOneProxy.enroll();
    }

    function test_confirm_cannot_enroll_twice() public {
        vm.startPrank(eli);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.prank(eli);
        vm.expectRevert(LevelOne.HH__StudentExists.selector);
        levelOneProxy.enroll();
    }

    modifier schoolInSession() {
        _teachersAdded();
        _studentsEnrolled();

        vm.prank(principal);
        levelOneProxy.startSession(100);

        _;
    }

    function test_confirm_can_give_review() public schoolInSession {
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(alice);
        levelOneProxy.giveReview(harriet, false);

        assert(levelOneProxy.studentScore(harriet) == 90);
    }

    function test_confirm_can_graduate() public schoolInSession {
        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);

        LevelTwo levelTwoProxy = LevelTwo(proxyAddress);

        console2.log(levelTwoProxy.bursary());
        console2.log(levelTwoProxy.getTotalStudents());
    }

    // ////////////////////////////////
    // /////                      /////
    // /////   HELPER FUNCTIONS   /////
    // /////                      /////
    // ////////////////////////////////

    function _teachersAdded() internal {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();
    }

    function _studentsEnrolled() internal {
        vm.startPrank(clara);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(dan);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(eli);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(fin);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(grey);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(harriet);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();
    }

    // Functions after this are all for POC

    // Test 1: Student's reviewCount not updated upon giveReview
    function test_student_reviewCount_update() public schoolInSession {
        assertEq(levelOneProxy.reviewCount(harriet), 0);

        vm.warp(block.timestamp + 1 weeks);
        vm.prank(alice);
        levelOneProxy.giveReview(harriet, false);
        assertEq(levelOneProxy.reviewCount(harriet), 0);
        
        vm.warp(block.timestamp + 1 weeks);
        vm.prank(alice);
        levelOneProxy.giveReview(harriet, false);
        assertEq(levelOneProxy.reviewCount(harriet), 0);        
    }

    // Test 2: Upgrade cannot occur if any student has not gotten 4 reviews
    function test_upgrade_without_4_reviews() public schoolInSession {
        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        assertEq(levelOneProxy.reviewCount(harriet), 0);

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);
    }

     // Test 3: System upgrade cannot take place unless school's sessionEnd has reached
    function test_upgrade_without_sessionend() public schoolInSession {
        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        assertLt(block.timestamp, levelOneProxy.getSessionEnd()); // assert that current timestamp is less than sessionEnd date
        assertTrue(levelOneProxy.getSessionStatus());

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);
    }

    // Test 4: System upgrade did not actually upgrade to new implemenation
    function test_upgrade_did_not_upgrade() public schoolInSession {
        bytes32 initialImplementation = vm.load(proxyAddress, ERC1967Utils.IMPLEMENTATION_SLOT);
        address initialImplementationAddress = address(uint160(uint256(initialImplementation)));

        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);

        bytes32 newImplementation = vm.load(proxyAddress, ERC1967Utils.IMPLEMENTATION_SLOT);
        address newImplementationAddress = address(uint160(uint256(newImplementation)));

        assertEq(initialImplementationAddress, newImplementationAddress); 
    }

    // Test 5: Students below cutoff score are not removed when upgraded
    function test_students_below_cutoff_not_removed() public schoolInSession {
        vm.warp(block.timestamp + 1 weeks);
        vm.prank(alice);
        levelOneProxy.giveReview(harriet, false);

        assertEq(levelOneProxy.getTotalStudents(), 6); // 6 students present initially
        assertEq(levelOneProxy.studentScore(harriet), 90);
        assertEq(levelOneProxy.cutOffScore(), 100);
        assertLt(levelOneProxy.studentScore(harriet), levelOneProxy.cutOffScore()); // assert that harriet did not meet the cutoff score

        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);

        LevelTwo levelTwoProxy = LevelTwo(proxyAddress);

        assertEq(levelTwoProxy.getTotalStudents(), 6); // all 6 students are still present
    }

    // Test 6: Disbursement of funds are wrong, teacher does not share 35% and bursary does not hold 60% left
    function test_payment_structure_wrong() public schoolInSession {
        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        uint256 initialBursary = schoolFees * 6; 
        assertEq(usdc.balanceOf(proxyAddress), initialBursary);

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);

        // 5% of 30k = 1500 -> principal
        // 35% of 30k = 10500 -> shared by teachers
        // 60% of 30k = 18000 -> remaining in bursary
        uint256 bursaryRemaining = 60 * initialBursary / 100;
        assertEq(usdc.balanceOf(proxyAddress), bursaryRemaining);
    }
}
