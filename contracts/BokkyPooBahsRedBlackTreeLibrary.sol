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
type PriceType is uint64;

library BokkyPooBahsRedBlackTreeLibrary {

    struct Node {
        PriceType parent;
        PriceType left;
        PriceType right;
        uint8 red;
    }

    struct Tree {
        PriceType root;
        mapping(PriceType => Node) nodes;
    }

    PriceType private constant EMPTY = PriceType.wrap(0);
    uint8 private constant RED_TRUE = 1;
    uint8 private constant RED_FALSE = 2; // Can also be 0 - check against RED_TRUE

    function first(Tree storage self) internal view returns (PriceType _key) {
        _key = self.root;
        if (PriceType.unwrap(_key) != PriceType.unwrap(EMPTY)) {
            while (PriceType.unwrap(self.nodes[_key].left) != PriceType.unwrap(EMPTY)) {
                _key = self.nodes[_key].left;
            }
        }
    }
    function last(Tree storage self) internal view returns (PriceType _key) {
        _key = self.root;
        if (PriceType.unwrap(_key) != PriceType.unwrap(EMPTY)) {
            while (PriceType.unwrap(self.nodes[_key].right) != PriceType.unwrap(EMPTY)) {
                _key = self.nodes[_key].right;
            }
        }
    }
    function next(Tree storage self, PriceType target) internal view returns (PriceType cursor) {
        require(PriceType.unwrap(target) != PriceType.unwrap(EMPTY));
        if (PriceType.unwrap(self.nodes[target].right) != PriceType.unwrap(EMPTY)) {
            cursor = treeMinimum(self, self.nodes[target].right);
        } else {
            cursor = self.nodes[target].parent;
            while (PriceType.unwrap(cursor) != PriceType.unwrap(EMPTY) && PriceType.unwrap(target) == PriceType.unwrap(self.nodes[cursor].right)) {
                target = cursor;
                cursor = self.nodes[cursor].parent;
            }
        }
    }
    function prev(Tree storage self, PriceType target) internal view returns (PriceType cursor) {
        require(PriceType.unwrap(target) != PriceType.unwrap(EMPTY));
        if (PriceType.unwrap(self.nodes[target].left) != PriceType.unwrap(EMPTY)) {
            cursor = treeMaximum(self, self.nodes[target].left);
        } else {
            cursor = self.nodes[target].parent;
            while (PriceType.unwrap(cursor) != PriceType.unwrap(EMPTY) && PriceType.unwrap(target) == PriceType.unwrap(self.nodes[cursor].left)) {
                target = cursor;
                cursor = self.nodes[cursor].parent;
            }
        }
    }
    function exists(Tree storage self, PriceType key) internal view returns (bool) {
        return (PriceType.unwrap(key) != PriceType.unwrap(EMPTY)) && ((PriceType.unwrap(key) == PriceType.unwrap(self.root)) || (PriceType.unwrap(self.nodes[key].parent) != PriceType.unwrap(EMPTY)));
    }
    function isEmpty(PriceType key) internal pure returns (bool) {
        return PriceType.unwrap(key) == PriceType.unwrap(EMPTY);
    }
    function getEmpty() internal pure returns (PriceType) {
        return EMPTY;
    }
    function getNode(Tree storage self, PriceType key) internal view returns (PriceType _returnKey, PriceType _parent, PriceType _left, PriceType _right, uint8 _red) {
        require(exists(self, key));
        return(key, self.nodes[key].parent, self.nodes[key].left, self.nodes[key].right, self.nodes[key].red);
    }

    function insert(Tree storage self, PriceType key) internal {
        require(PriceType.unwrap(key) != PriceType.unwrap(EMPTY));
        require(!exists(self, key));
        PriceType cursor = EMPTY;
        PriceType probe = self.root;
        while (PriceType.unwrap(probe) != PriceType.unwrap(EMPTY)) {
            cursor = probe;
            if (PriceType.unwrap(key) < PriceType.unwrap(probe)) {
                probe = self.nodes[probe].left;
            } else {
                probe = self.nodes[probe].right;
            }
        }
        self.nodes[key] = Node({parent: cursor, left: EMPTY, right: EMPTY, red: RED_TRUE});
        if (PriceType.unwrap(cursor) == PriceType.unwrap(EMPTY)) {
            self.root = key;
        } else if (PriceType.unwrap(key) < PriceType.unwrap(cursor)) {
            self.nodes[cursor].left = key;
        } else {
            self.nodes[cursor].right = key;
        }
        insertFixup(self, key);
    }
    function remove(Tree storage self, PriceType key) internal {
        require(PriceType.unwrap(key) != PriceType.unwrap(EMPTY));
        require(exists(self, key));
        PriceType probe;
        PriceType cursor;
        if (PriceType.unwrap(self.nodes[key].left) == PriceType.unwrap(EMPTY) || PriceType.unwrap(self.nodes[key].right) == PriceType.unwrap(EMPTY)) {
            cursor = key;
        } else {
            cursor = self.nodes[key].right;
            while (PriceType.unwrap(self.nodes[cursor].left) != PriceType.unwrap(EMPTY)) {
                cursor = self.nodes[cursor].left;
            }
        }
        if (PriceType.unwrap(self.nodes[cursor].left) != PriceType.unwrap(EMPTY)) {
            probe = self.nodes[cursor].left;
        } else {
            probe = self.nodes[cursor].right;
        }
        PriceType yParent = self.nodes[cursor].parent;
        self.nodes[probe].parent = yParent;
        if (PriceType.unwrap(yParent) != PriceType.unwrap(EMPTY)) {
            if (PriceType.unwrap(cursor) == PriceType.unwrap(self.nodes[yParent].left)) {
                self.nodes[yParent].left = probe;
            } else {
                self.nodes[yParent].right = probe;
            }
        } else {
            self.root = probe;
        }
        bool doFixup = self.nodes[cursor].red != RED_TRUE;
        if (PriceType.unwrap(cursor) != PriceType.unwrap(key)) {
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

    function treeMinimum(Tree storage self, PriceType key) private view returns (PriceType) {
        while (PriceType.unwrap(self.nodes[key].left) != PriceType.unwrap(EMPTY)) {
            key = self.nodes[key].left;
        }
        return key;
    }
    function treeMaximum(Tree storage self, PriceType key) private view returns (PriceType) {
        while (PriceType.unwrap(self.nodes[key].right) != PriceType.unwrap(EMPTY)) {
            key = self.nodes[key].right;
        }
        return key;
    }

    function rotateLeft(Tree storage self, PriceType key) private {
        PriceType cursor = self.nodes[key].right;
        PriceType keyParent = self.nodes[key].parent;
        PriceType cursorLeft = self.nodes[cursor].left;
        self.nodes[key].right = cursorLeft;
        if (PriceType.unwrap(cursorLeft) != PriceType.unwrap(EMPTY)) {
            self.nodes[cursorLeft].parent = key;
        }
        self.nodes[cursor].parent = keyParent;
        if (PriceType.unwrap(keyParent) == PriceType.unwrap(EMPTY)) {
            self.root = cursor;
        } else if (PriceType.unwrap(key) == PriceType.unwrap(self.nodes[keyParent].left)) {
            self.nodes[keyParent].left = cursor;
        } else {
            self.nodes[keyParent].right = cursor;
        }
        self.nodes[cursor].left = key;
        self.nodes[key].parent = cursor;
    }
    function rotateRight(Tree storage self, PriceType key) private {
        PriceType cursor = self.nodes[key].left;
        PriceType keyParent = self.nodes[key].parent;
        PriceType cursorRight = self.nodes[cursor].right;
        self.nodes[key].left = cursorRight;
        if (PriceType.unwrap(cursorRight) != PriceType.unwrap(EMPTY)) {
            self.nodes[cursorRight].parent = key;
        }
        self.nodes[cursor].parent = keyParent;
        if (PriceType.unwrap(keyParent) == PriceType.unwrap(EMPTY)) {
            self.root = cursor;
        } else if (PriceType.unwrap(key) == PriceType.unwrap(self.nodes[keyParent].right)) {
            self.nodes[keyParent].right = cursor;
        } else {
            self.nodes[keyParent].left = cursor;
        }
        self.nodes[cursor].right = key;
        self.nodes[key].parent = cursor;
    }

    function insertFixup(Tree storage self, PriceType key) private {
        PriceType cursor;
        while (PriceType.unwrap(key) != PriceType.unwrap(self.root) && self.nodes[self.nodes[key].parent].red == RED_TRUE) {
            PriceType keyParent = self.nodes[key].parent;
            if (PriceType.unwrap(keyParent) == PriceType.unwrap(self.nodes[self.nodes[keyParent].parent].left)) {
                cursor = self.nodes[self.nodes[keyParent].parent].right;
                if (self.nodes[cursor].red == RED_TRUE) {
                    self.nodes[keyParent].red = RED_FALSE;
                    self.nodes[cursor].red = RED_FALSE;
                    self.nodes[self.nodes[keyParent].parent].red = RED_TRUE;
                    key = self.nodes[keyParent].parent;
                } else {
                    if (PriceType.unwrap(key) == PriceType.unwrap(self.nodes[keyParent].right)) {
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
                    if (PriceType.unwrap(key) == PriceType.unwrap(self.nodes[keyParent].left)) {
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

    function replaceParent(Tree storage self, PriceType a, PriceType b) private {
        PriceType bParent = self.nodes[b].parent;
        self.nodes[a].parent = bParent;
        if (PriceType.unwrap(bParent) == PriceType.unwrap(EMPTY)) {
            self.root = a;
        } else {
            if (PriceType.unwrap(b) == PriceType.unwrap(self.nodes[bParent].left)) {
                self.nodes[bParent].left = a;
            } else {
                self.nodes[bParent].right = a;
            }
        }
    }
    function removeFixup(Tree storage self, PriceType key) private {
        PriceType cursor;
        while (PriceType.unwrap(key) != PriceType.unwrap(self.root) && self.nodes[key].red != RED_TRUE) {
            PriceType keyParent = self.nodes[key].parent;
            if (PriceType.unwrap(key) == PriceType.unwrap(self.nodes[keyParent].left)) {
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
