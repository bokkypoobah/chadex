pragma solidity ^0.8.0;

// ----------------------------------------------------------------------------
// BokkyPooBah's Red-Black Tree Library v1.0-pre-release-a
//
// A Solidity Red-Black Tree binary search library to store and access a sorted
// list of unsigned integer data. The Red-Black algorithm rebalances the binary
// search tree, resulting in O(log n) insert, remove and search time (and ~gas)
//
// https://github.com/bokkypoobah/BokkyPooBahsRedBlackTreeLibrary
//
// SPDX-License-Identifier: MIT
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2020. The MIT Licence.
// ----------------------------------------------------------------------------
type Price is uint64; // 2^64 = 18, 446,744,073, 709,552,000

library BokkyPooBahsRedBlackTreeLibrary {

    struct Node {
        Price parent;
        Price left;
        Price right;
        uint8 red;
    }

    struct Tree {
        Price root;
        mapping(Price => Node) nodes;
    }

    Price private constant EMPTY = Price.wrap(0);
    uint8 private constant RED_TRUE = 1;
    uint8 private constant RED_FALSE = 2; // Can also be 0 - check against RED_TRUE

    error CannotFindNextEmptyKey();
    error CannotFindPrevEmptyKey();
    error CannotInsertEmptyKey();
    error CannotInsertExistingKey();
    error CannotRemoveEmptyKey();
    error CannotRemoveMissingKey();

    function first(Tree storage self) internal view returns (Price key) {
        key = self.root;
        if (isNotEmpty(key)) {
            while (isNotEmpty(self.nodes[key].left)) {
                key = self.nodes[key].left;
            }
        }
    }
    function last(Tree storage self) internal view returns (Price key) {
        key = self.root;
        if (isNotEmpty(key)) {
            while (isNotEmpty(self.nodes[key].right)) {
                key = self.nodes[key].right;
            }
        }
    }
    function next(Tree storage self, Price target) internal view returns (Price cursor) {
        if (isEmpty(target)) {
            revert CannotFindNextEmptyKey();
        }
        if (isNotEmpty(self.nodes[target].right)) {
            cursor = treeMinimum(self, self.nodes[target].right);
        } else {
            cursor = self.nodes[target].parent;
            while (isNotEmpty(cursor) && Price.unwrap(target) == Price.unwrap(self.nodes[cursor].right)) {
                target = cursor;
                cursor = self.nodes[cursor].parent;
            }
        }
    }
    function prev(Tree storage self, Price target) internal view returns (Price cursor) {
        if (isEmpty(target)) {
            revert CannotFindPrevEmptyKey();
        }
        if (isNotEmpty(self.nodes[target].left)) {
            cursor = treeMaximum(self, self.nodes[target].left);
        } else {
            cursor = self.nodes[target].parent;
            while (isNotEmpty(cursor) && Price.unwrap(target) == Price.unwrap(self.nodes[cursor].left)) {
                target = cursor;
                cursor = self.nodes[cursor].parent;
            }
        }
    }
    function exists(Tree storage self, Price key) internal view returns (bool) {
        return isNotEmpty(key) && ((Price.unwrap(key) == Price.unwrap(self.root)) || isNotEmpty(self.nodes[key].parent));
    }
    function isEmpty(Price key) internal pure returns (bool) {
        return Price.unwrap(key) == Price.unwrap(EMPTY);
    }
    function isNotEmpty(Price key) internal pure returns (bool) {
        return Price.unwrap(key) != Price.unwrap(EMPTY);
    }
    function getEmpty() internal pure returns (Price) {
        return EMPTY;
    }
    function getNode(Tree storage self, Price key) internal view returns (Price returnKey, Price parent, Price left, Price right, uint8 red) {
        require(exists(self, key));
        return(key, self.nodes[key].parent, self.nodes[key].left, self.nodes[key].right, self.nodes[key].red);
    }

    function insert(Tree storage self, Price key) internal {
        if (isEmpty(key)) {
            revert CannotInsertEmptyKey();
        }
        if (exists(self, key)) {
            revert CannotInsertExistingKey();
        }
        Price cursor = EMPTY;
        Price probe = self.root;
        while (isNotEmpty(probe)) {
            cursor = probe;
            if (Price.unwrap(key) < Price.unwrap(probe)) {
                probe = self.nodes[probe].left;
            } else {
                probe = self.nodes[probe].right;
            }
        }
        self.nodes[key] = Node({parent: cursor, left: EMPTY, right: EMPTY, red: RED_TRUE});
        if (isEmpty(cursor)) {
            self.root = key;
        } else if (Price.unwrap(key) < Price.unwrap(cursor)) {
            self.nodes[cursor].left = key;
        } else {
            self.nodes[cursor].right = key;
        }
        insertFixup(self, key);
    }
    function remove(Tree storage self, Price key) internal {
        if (isEmpty(key)) {
            revert CannotRemoveEmptyKey();
        }
        if (!exists(self, key)) {
            revert CannotRemoveMissingKey();
        }
        Price probe;
        Price cursor;
        if (isEmpty(self.nodes[key].left) || isEmpty(self.nodes[key].right)) {
            cursor = key;
        } else {
            cursor = self.nodes[key].right;
            while (isNotEmpty(self.nodes[cursor].left)) {
                cursor = self.nodes[cursor].left;
            }
        }
        if (isNotEmpty(self.nodes[cursor].left)) {
            probe = self.nodes[cursor].left;
        } else {
            probe = self.nodes[cursor].right;
        }
        Price yParent = self.nodes[cursor].parent;
        self.nodes[probe].parent = yParent;
        if (isNotEmpty(yParent)) {
            if (Price.unwrap(cursor) == Price.unwrap(self.nodes[yParent].left)) {
                self.nodes[yParent].left = probe;
            } else {
                self.nodes[yParent].right = probe;
            }
        } else {
            self.root = probe;
        }
        bool doFixup = self.nodes[cursor].red != RED_TRUE;
        if (Price.unwrap(cursor) != Price.unwrap(key)) {
            replaceParent(self, cursor, key);
            self.nodes[cursor].left = self.nodes[key].left;
            self.nodes[self.nodes[cursor].left].parent = cursor;
            self.nodes[cursor].right = self.nodes[key].right;
            self.nodes[self.nodes[cursor].right].parent = cursor;
            self.nodes[cursor].red = self.nodes[key].red;
            (cursor, key) = (key, cursor);
        }
        if (doFixup) {
            removeFixup(self, probe);
        }
        delete self.nodes[cursor];
    }

    function treeMinimum(Tree storage self, Price key) private view returns (Price) {
        while (isNotEmpty(self.nodes[key].left)) {
            key = self.nodes[key].left;
        }
        return key;
    }
    function treeMaximum(Tree storage self, Price key) private view returns (Price) {
        while (isNotEmpty(self.nodes[key].right)) {
            key = self.nodes[key].right;
        }
        return key;
    }

    function rotateLeft(Tree storage self, Price key) private {
        Price cursor = self.nodes[key].right;
        Price keyParent = self.nodes[key].parent;
        Price cursorLeft = self.nodes[cursor].left;
        self.nodes[key].right = cursorLeft;
        if (isNotEmpty(cursorLeft)) {
            self.nodes[cursorLeft].parent = key;
        }
        self.nodes[cursor].parent = keyParent;
        if (isEmpty(keyParent)) {
            self.root = cursor;
        } else if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].left)) {
            self.nodes[keyParent].left = cursor;
        } else {
            self.nodes[keyParent].right = cursor;
        }
        self.nodes[cursor].left = key;
        self.nodes[key].parent = cursor;
    }
    function rotateRight(Tree storage self, Price key) private {
        Price cursor = self.nodes[key].left;
        Price keyParent = self.nodes[key].parent;
        Price cursorRight = self.nodes[cursor].right;
        self.nodes[key].left = cursorRight;
        if (isNotEmpty(cursorRight)) {
            self.nodes[cursorRight].parent = key;
        }
        self.nodes[cursor].parent = keyParent;
        if (isEmpty(keyParent)) {
            self.root = cursor;
        } else if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].right)) {
            self.nodes[keyParent].right = cursor;
        } else {
            self.nodes[keyParent].left = cursor;
        }
        self.nodes[cursor].right = key;
        self.nodes[key].parent = cursor;
    }

    function insertFixup(Tree storage self, Price key) private {
        Price cursor;
        while (Price.unwrap(key) != Price.unwrap(self.root) && self.nodes[self.nodes[key].parent].red == RED_TRUE) {
            Price keyParent = self.nodes[key].parent;
            if (Price.unwrap(keyParent) == Price.unwrap(self.nodes[self.nodes[keyParent].parent].left)) {
                cursor = self.nodes[self.nodes[keyParent].parent].right;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    key = self.nodes[keyParent].parent;
                } else {
                    if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].right)) {
                      key = keyParent;
                      rotateLeft(self, key);
                    }
                    keyParent = self.nodes[key].parent;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    rotateRight(self, self.nodes[keyParent].parent);
                }
            } else {
                cursor = self.nodes[self.nodes[keyParent].parent].left;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    key = self.nodes[keyParent].parent;
                } else {
                    if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].left)) {
                      key = keyParent;
                      rotateRight(self, key);
                    }
                    keyParent = self.nodes[key].parent;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    rotateLeft(self, self.nodes[keyParent].parent);
                }
            }
        }
        self.nodes[self.root].red = RED_FALSE;
    }

    function replaceParent(Tree storage self, Price a, Price b) private {
        Price bParent = self.nodes[b].parent;
        self.nodes[a].parent = bParent;
        if (isEmpty(bParent)) {
            self.root = a;
        } else {
            if (Price.unwrap(b) == Price.unwrap(self.nodes[bParent].left)) {
                self.nodes[bParent].left = a;
            } else {
                self.nodes[bParent].right = a;
            }
        }
    }
    function removeFixup(Tree storage self, Price key) private {
        Price cursor;
        while (Price.unwrap(key) != Price.unwrap(self.root) && self.nodes[key].red != RED_TRUE) {
            Price keyParent = self.nodes[key].parent;
            if (Price.unwrap(key) == Price.unwrap(self.nodes[keyParent].left)) {
                cursor = self.nodes[keyParent].right;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[keyParent].red = RED_TRUE;
                    rotateLeft(self, keyParent);
                    cursor = self.nodes[keyParent].right;
                }
                if (self.nodes[self.nodes[cursor].left].red != RED_TRUE && self.nodes[self.nodes[cursor].right].red != RED_TRUE) {
                    self.nodes[cursor].red = RED_TRUE;
                    key = keyParent;
                } else {
                    if (self.nodes[self.nodes[cursor].right].red != RED_TRUE) {
                        self.nodes[self.nodes[cursor].left].red = RED_FALSE;
                        self.nodes[cursor].red = RED_TRUE;
                        rotateRight(self, cursor);
                        cursor = self.nodes[keyParent].right;
                    }
                    self.nodes[cursor].red = self.nodes[keyParent].red;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[cursor].right].red = RED_FALSE;
                    rotateLeft(self, keyParent);
                    key = self.root;
                }
            } else {
                cursor = self.nodes[keyParent].left;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[keyParent].red = RED_TRUE;
                    rotateRight(self, keyParent);
                    cursor = self.nodes[keyParent].left;
                }
                if (self.nodes[self.nodes[cursor].right].red != RED_TRUE && self.nodes[self.nodes[cursor].left].red != RED_TRUE) {
                    self.nodes[cursor].red = RED_TRUE;
                    key = keyParent;
                } else {
                    if (self.nodes[self.nodes[cursor].left].red != RED_TRUE) {
                        self.nodes[self.nodes[cursor].right].red = RED_FALSE;
                        self.nodes[cursor].red = RED_TRUE;
                        rotateLeft(self, cursor);
                        cursor = self.nodes[keyParent].left;
                    }
                    self.nodes[cursor].red = self.nodes[keyParent].red;
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[self.nodes[cursor].left].red = RED_FALSE;
                    rotateRight(self, keyParent);
                    key = self.root;
                }
            }
        }
        self.nodes[key].red = RED_FALSE;
    }
}
// ----------------------------------------------------------------------------
// End - BokkyPooBah's Red-Black Tree Library
// ----------------------------------------------------------------------------
